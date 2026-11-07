--!native
--!optimize 2

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Projectile = require(script.Parent.Projectile)
const types = require(script.Parent.Parent.types)

--[=[ TimeStopFreeze

   The shared "time stops here" machinery, extracted from the Time Stop skill
   so a finisher can reuse it without duplicating the freeze semantics:
   everyone in the radius freezes (DamageHold + Restrain + HumanoidRootPart
   anchored), animations halt on both sides (server and client-side, through
   the shared Animation VFX), projectiles stand still, active skill sequences
   are paused and resumed with the world.

   `apply` is self-contained per call: the anchor list lives in the closure
   and is restored exactly when the freeze ends (or the cleaner is destroyed
   early by an interrupt). Only the HumanoidRootPart is anchored — one
   anchored part freezes the whole Motor6D assembly. The finisher victim is
   `victim` for the call: no anchor at all (the grab holds them), only
   Restrain + DamageHold.

   Caught players who do not carry `TimeStopVision` in their spec or subspec
   get a private illusion: the caster (and their stand) is pinned mid-pose on
   their screen through the `TimeStopHold` VFX, their clips held on that side
   too. The audience always gets both back through this same cleaner.

   The caster is never frozen — they get DamageHold so hits cannot land on
   them either.
]=]

type FreezeAssets = {
	Bubble: Instance?,
	MainSmo4ok: Instance?,
	TS_CC: Instance?,
	Tick: any?,
	End: any?,
	[string]: any,
}

export type FreezeContext = {
	combatService: any,
	vfxService: any,
	character: types.Character,
	castCleaner: any,
	duration: number,
	assets: FreezeAssets,
	skill: any?,
	victim: types.Character?,
	radius: number?,
	onEnd: ((castCleaner: any) -> ())?,
}

const DEFAULT_RADIUS = 100

-- The beat between the anchors coming back and the queued attacks draining,
-- so the un-anchor replicates to clients before queued knockbacks replay.
const RESUME_BEAT = 0.25

const players = function()
	return Players:GetPlayers()
end

const function targetsInRadius(
	combatService: any,
	character: types.Character,
	radius: number,
	skill: any?
): { types.Character }
	const unique: { types.Character } = {}
	const seen: { [types.Character]: boolean } = {}

	for _, target in
		combatService:Hitbox({
			Skill = skill,
			Caster = character,
			Info = {
				Size = radius,
				Origin = CFrame.new(character.RootPart.CFrame.Position),
			},
		})
	do
		if target == character or seen[target] then continue end
		seen[target] = true
		table.insert(unique, target)
	end

	return unique
end

const function pauseSequences(targets: { types.Character }): { types.Skill }
	const paused: { types.Skill } = {}

	for _, target in targets do
		for _, spec in { target.Spec, target.SubSpec } do
			if not spec then continue end

			for _, skill in spec.Skills do
				const sequence = skill.Sequence
				if sequence and sequence:IsPlaying() then
					skill:Pause()
					table.insert(paused, skill)
				end
			end
		end
	end

	return paused
end

const function pauseServerTracks(models: { Model }): { { track: AnimationTrack, speed: number } }
	const snapshot: { { track: AnimationTrack, speed: number } } = {}

	for _, model in models do
		for _, descendant in model:GetDescendants() do
			if not descendant:IsA("Animator") then continue end
			for _, track in descendant:GetPlayingAnimationTracks() do
				if track.Speed == 0 then continue end
				table.insert(snapshot, { track = track, speed = track.Speed })
				track:AdjustSpeed(0)
			end
		end
	end

	return snapshot
end

const function resumeServerTracks(snapshot: { { track: AnimationTrack, speed: number } })
	for _, entry in snapshot do
		pcall(function()
			entry.track:AdjustSpeed(entry.speed)
		end)
	end
	table.clear(snapshot)
end

const function frozenModels(targets: { types.Character }): { Model }
	const standService = Crane:GetService("StandService")
	const models: { Model } = {}

	for _, target in targets do
		table.insert(models, target.instance)
		const stand = standService:GetStand(target)
		const standInstance = stand and stand.instance
		if standInstance and standInstance:IsA("Model") then table.insert(models, standInstance) end
	end

	return models
end

const TimeStopFreeze = {}

function TimeStopFreeze.apply(ctx: FreezeContext)
	const combatService = ctx.combatService
	const vfxService = ctx.vfxService
	const character = ctx.character
	const castCleaner = ctx.castCleaner
	const duration = ctx.duration
	const tsAssets = ctx.assets
	const radius = ctx.radius or DEFAULT_RADIUS
	const anchored: { { part: BasePart, wasAnchored: boolean } } = {}

	const others = targetsInRadius(combatService, character, radius, ctx.skill)
	const holdModels = frozenModels(others)

	-- Animation hold, both sides: server tracks through Animate, client clips
	-- through the shared Animation VFX (bulk form passed as the first arg).
	const pausedTracks = pauseServerTracks(holdModels)
	vfxService:StartEffect(players(), "Animation", { PauseAll = holdModels })

	-- Registered first so LIFO it runs last, after Restrain and DamageHold.
	castCleaner:Add(function()
		resumeServerTracks(pausedTracks)
		vfxService:StartEffect(players(), "Animation", { ResumeAll = holdModels })
	end)

	const pausedSkills = pauseSequences(others)
	castCleaner:Add(function()
		for _, skill in pausedSkills do
			skill:Resume()
		end
	end)

	const zoneId = Projectile.FreezeZone(character.RootPart.CFrame.Position, radius)
	castCleaner:Add(function()
		Projectile.UnfreezeZone(zoneId)
	end)

	castCleaner:Add(character:AddParameter("DamageHold", true))
	for _, target in others do
		const restrain = target:AddParameter("Restrain", true)
		const damageHold = target:AddParameter("DamageHold", true)

		castCleaner:Add(function()
			task.delay(RESUME_BEAT, function()
				restrain:Destroy()
				damageHold:Destroy()
			end)
		end)

		if target == ctx.victim then continue end
		const root = target.instance:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			table.insert(anchored, { part = root, wasAnchored = root.Anchored })
			root.Anchored = true
		end
	end

	-- The private stasis audience: caught players without TimeStopVision.
	const stasisAudience: { Player } = {}
	for _, target in others do
		const specVision = target.Spec and target.Spec.Data.TimeStopVision == true
		const subVision = target.SubSpec and target.SubSpec.Data.TimeStopVision == true
		if specVision or subVision then continue end
		if target.Player then table.insert(stasisAudience, target.Player) end
	end

	const casterModels: { Model } = { character.instance }
	local standModel: Model? = nil
	const casterStand = Crane:GetService("StandService"):GetStand(character)
	const casterStandInstance = casterStand and casterStand.instance
	if casterStandInstance and casterStandInstance:IsA("Model") then
		standModel = casterStandInstance
		table.insert(casterModels, standModel)
	end

	if #stasisAudience > 0 then
		vfxService:StartEffect(stasisAudience, "Animation", { PauseAll = casterModels })
		vfxService:StartEffect(stasisAudience, "TimeStopHold", {
			Caster = character.instance,
			Stand = standModel,
			Duration = duration,
		})
	end

	castCleaner:Add(function()
		if #stasisAudience == 0 then return end
		vfxService:StartEffect(stasisAudience, "Animation", { ResumeAll = casterModels })
		vfxService:StopEffect(stasisAudience, "TimeStopHold", {
			Caster = character.instance,
			Stand = standModel,
		})
	end)

	-- Un-anchor: registered last so LIFO it runs first, before the held
	-- parameters are released a beat later.
	castCleaner:Add(function()
		for _, entry in anchored do
			if entry.part.Parent then entry.part.Anchored = entry.wasAnchored end
		end
		table.clear(anchored)
	end)

	vfxService:StartEffect(players(), "TimeStop", {
		Type = "Release",
		Character = character.instance,
		Duration = duration,
		Radius = radius,
		BubbleTemplate = tsAssets.Bubble,
		SmoothTemplate = tsAssets.MainSmo4ok,
	})
	vfxService:StartEffect(players(), "TimeStop", {
		Type = "ClientImpact",
		Character = character.instance,
		Duration = duration,
		TSCCTemplate = tsAssets.TS_CC,
		TickSound = tsAssets.Tick,
	})

	castCleaner:Delay(duration, function()
		vfxService:StartEffect(players(), "TimeStop", {
			Type = "End",
			Character = character.instance,
			Duration = duration,
			EndSound = tsAssets.End,
		})

		if ctx.onEnd then ctx.onEnd(castCleaner) end

		castCleaner:Destroy()
	end)
end

return TimeStopFreeze
