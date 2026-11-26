const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const Config = require(ReplicatedStorage.shared.configs.SeveredLimbs)
const types = require(ServerScriptService.server.types)

const VFXService = Crane:GetService("VFXService")
const SeverAssets = ReplicatedStorage.assets:WaitForChild(Config.AssetsRoot)

-- Wounds are a global mechanic, not a spec asset: every character resolves
-- the same placeholder clips and limb models regardless of their skin.
const function globalClip(name: string): string?
	const clip = SeverAssets.Animations:FindFirstChild(name)
	return clip and (clip :: Animation).AnimationId or nil
end

-- Enums.Limb uses compact names; the character rigs in this project are R6
-- and their parts contain spaces.
const RIG_PARTS = {
	[Enums.Limb.Head] = "Head",
	[Enums.Limb.Torso] = "Torso",
	[Enums.Limb.LeftArm] = "Left Arm",
	[Enums.Limb.RightArm] = "Right Arm",
	[Enums.Limb.LeftLeg] = "Left Leg",
	[Enums.Limb.RightLeg] = "Right Leg",
} :: { [string]: string }

return {
	Name = "Sever",
	Type = "Cast",
	Priority = 95,

	Function = function(Data: types.AttackData)
		const Info = Data.Info
		if not Data.State.Success then return true end
		if not Info.Sever then return true end

		const victim = Data.Victim
		if victim.Humanoid.Health <= 0 then return true end

		const limb = Info.Sever.Limb
		const now = workspace:GetServerTimeNow()
		const uuid = tostring(os.clock()) .. limb
		const isLeg = limb == Enums.Limb.LeftLeg or limb == Enums.Limb.RightLeg
		const isArm = limb == Enums.Limb.LeftArm or limb == Enums.Limb.RightArm

		const wound = victim:AddParameter(
			"SeveredLimbs" :: any,
			{
				[limb] = {
					UUID = uuid,
					ExpiresAt = now + Info.Sever.Duration,
					WalkSpeed = if isLeg then Enums.CastSpeed.Medium else nil,
					DamageMultiplier = if isArm then 0.5 else nil,
					Walk = if isLeg then globalClip(Config.Animations.Crawl) else nil,
					Run = if isLeg then globalClip(Config.Animations.Run) else nil,
					Idle = if isLeg then globalClip(Config.Animations.Idle) else nil,
				},
			} :: any
		)
		victim.Cleaner:Add(wound)

		-- The parameter watcher only folds state; it never sees the expired
		-- entry after Destroy(), so effect teardown must be explicit here.
		local stopped = false
		const function stop()
			if stopped then return end
			stopped = true
			if not victim.TornDown then wound:Destroy() end
			VFXService:StopEffect(Players:GetPlayers(), "SeveredLimb", { UUID = uuid })
			VFXService:StopEffect(Players:GetPlayers(), "BloodFXBurst", { UUID = uuid })
		end
		victim.Cleaner:Add(stop)
		task.delay(Info.Sever.Duration, stop)

		-- The client clones the victim's own limb part (with its colours and
		-- accessories) and spawns it at this CFrame. The global model is only a
		-- fallback for rigs that do not expose the expected part name.
		const model = SeverAssets.Models:FindFirstChild((Config.Models :: any)[limb] or limb)
		const rigPart = victim.instance:FindFirstChild(RIG_PARTS[limb] or limb)
		const origin = if rigPart and rigPart:IsA("BasePart")
			then rigPart.CFrame
			else victim.RootPart.CFrame

		VFXService:StartEffect(Players:GetPlayers(), "SeveredLimb", {
			UUID = uuid,
			Character = victim.instance,
			Limb = limb,
			Model = model,
			Origin = origin,
		})
		VFXService:StartEffect(Players:GetPlayers(), "BloodFXBurst", {
			UUID = uuid,
			Character = victim.instance,
			Limb = limb,
			Preset = "Fountain",
		})

		return true
	end,
}
