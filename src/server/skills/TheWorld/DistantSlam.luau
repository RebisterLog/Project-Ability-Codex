--[=[
	Distant Slam

	Telegraphs and then lands a remote kick on the nearest fully marked enemy.
	The stand is welded to the victim's root; the caster stays put and is slowed
	until both sequences finish. No time stop is involved.

	ASSETS:
	Animations
	   Animations/DistantSlamCast, Stand/Animations/DistantSlam
	Sounds
	   Sounds/DistantSlamCast, Stand/Sounds/DistantSlam
	Models
	   Models/DistantSlamWarning : warning ParticleEmitter on the stand
]=]

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Distant Slam",
	Tag = "OnlyForStand",
	SearchRadius = 25,

	SkillCharacters = { "Hit", "Blockable", "PerfectBlock", "Ragdoll" },

	AttackInfo = {
		Damage = 25,
		-- A perfect block parries; an ordinary block is passed through.
		-- BlockIgnore would disable the perfect-block branch entirely.
		Block = {
			Blockable = false,
			PerfectBlockable = true,
			BlockBreak = false,
			BlockCancel = false,
			BlockIgnore = false,
		},
		Ragdoll = { Duration = Enums.Ragdoll.Light },
		Knockback = { Push = 8, Hold = 0.1, Direction = { Mode = "Custom", Vector = Vector3.zero } },
		HitAnimations = "Default",
		HitEffects = { { Particle = "Default", Sound = "Default" } },
	} :: types.AttackInfo,
}

local function getMarkedKnives(self: types.Skill): any?
	if not self.MarkedKnives then self.MarkedKnives = self.Character.MarkedKnives end
	return self.MarkedKnives
end

local function clearAllMarks(self: types.Skill)
	-- Called once the slam commits to a target: every mark is consumed whether
	-- the hitbox connects or not. Marks are kept when no full mark exists or
	-- when the full mark was out of range.
	const marked = getMarkedKnives(self)
	if marked and marked.Marks then
		for target, _ in marked.Marks do
			marked.Clear(target)
		end
	end
end

local function findTarget(self: types.Skill): types.Character?
	const marked = getMarkedKnives(self)
	if not marked or not marked.Marks then return nil end

	local nearest: types.Character? = nil
	local best = self.Data.SearchRadius :: number

	for target, entry in marked.Marks do
		if entry.Count < 3 then continue end
		const dist = (target.RootPart.Position - self.Character.RootPart.Position).Magnitude
		if dist < best then
			best = dist
			nearest = target
		end
	end
	return nearest
end

function Skill:onInit()
	const character = self.Character :: types.Character
	const CombatService = Crane:GetService("CombatService")
	const VFXService = Crane:GetService("VFXService")

	self.StrikeSequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				20,
				function()
					const target = self.Target
					if not target or target.Humanoid.Health <= 0 then return end

					const info = table.clone(self.Data.AttackInfo)
					info.Knockback = table.clone(self.Data.AttackInfo.Knockback)
					info.Knockback.Direction = {
						Mode = "Custom",
						Vector = target.RootPart.CFrame.LookVector,
					}

					const hit = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = {
							Size = Vector3.new(5, 5, 5),
							Origin = CFrame.new(target.RootPart.Position),
						},
					})

					for _, candidate in hit do
						if candidate ~= target then continue end
						CombatService:Attack({
							Attacker = character,
							Victim = target,
							Info = info,
						})
					end
					-- Marks are consumed whether the hitbox connects or not.
					clearAllMarks(self)
				end,
			},
			{ 35 },
		},
	}))

	self.TelegraphSequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					const target = self.Target
					const stand =
						Crane:GetService("StandService"):GetStand(character) :: types.Stand
					if not target or not stand then return end

					-- Everything that must outlive the telegraph lives in the
					-- strike sequence's cleaner. Stopping either sequence on
					-- interrupt therefore releases all of it exactly once.
					self.StrikeSequence.Cleaner:Add(
						character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Medium)
					)
					self.StrikeSequence.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					stand:WeldTo(target.RootPart)
					self.StrikeSequence.Cleaner:Add(function()
						stand:WeldToOwner()
						if not character.Player then stand:HandleMovement() end
					end)

					self.WarningUUID = os.clock()
					VFXService:StartEffect(Players:GetPlayers(), "DistantSlamWarning", {
						UUID = self.WarningUUID,
						Caster = character.instance,
						Target = target.instance,
						Stand = stand.instance,
						Duration = 1.5,
					})
					self.StrikeSequence.Cleaner:Add(function()
						VFXService:StopEffect(Players:GetPlayers(), "DistantSlamWarning", {
							UUID = self.WarningUUID,
						})
						VFXService:StopEffect(Players:GetPlayers(), "Animation", {
							Character = stand.instance,
							Animation = self:GetAsset("Stand/Animations/DistantSlam").Animation,
						})
					end)

					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = stand.instance,
						Animation = self:GetAsset("Stand/Animations/DistantSlam"),
						Speed = seq.Speed,
					})

					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = character.RootPart,
						Sound = self:GetAsset("Sounds/DistantSlamCast"),
					})
				end,
			},

			{
				45,
				function()
					if self.StrikeSequence then
						self.StrikeSequence:Play()
						self.StrikeSequence:Await()
					end
				end,
			},

			{ 50 },
		},
	}))
end

function Skill:Activate()
	const marked = getMarkedKnives(self)
	if not marked or not marked.Marks then return end

	-- No full mark means a silent exit: no cooldown and no mark cleanup.
	local hasFullMark = false
	for _, entry in marked.Marks do
		if entry.Count >= 3 then
			hasFullMark = true
			break
		end
	end
	if not hasFullMark then return end

	-- Any committed cast spends the cooldown, whether the hitbox connects or
	-- not. The engine no longer overwrites it with Cooldown = 0 on return.
	self:SetCooldown(20)

	const target = findTarget(self)
	if not target then
		-- A full mark out of range still spends the cooldown, but is kept.
		return
	end

	self.Target = target

	if self.TelegraphSequence then
		self.TelegraphSequence:Play()
		self.TelegraphSequence:Await()
	end
	if self.StrikeSequence then self.StrikeSequence:Await() end
end

function Skill:Interrupt()
	if self.TelegraphSequence then self.TelegraphSequence:Stop() end
	if self.StrikeSequence then
		self.StrikeSequence:Stop()
		-- Stop() is a no-op while the sequence has not started, so clean its
		-- Butler explicitly: that is where WeldToOwner and VFX teardown live.
		self.StrikeSequence.Cleaner:Clean()
	end
end

return Skill
