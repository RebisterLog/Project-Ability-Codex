--[=[
	Distance Slam

	Automatically picks the nearest enemy within 50 studs, telegraphs, then
	lands a remote kick on them. The stand is welded to the victim's root;
	the caster stays put and is slowed from the cast through the strike.
	No time stop is involved.

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
	DisplayName = "Distance Slam",
	Tag = "OnlyForStand",
	SearchRadius = 50,

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
							Debug = true,
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
					-- The strike is awaited by Activate, not here: blocking
					-- this frame callback would stall the telegraph itself.
					if self.StrikeSequence then self.StrikeSequence:Play() end
				end,
			},

			{ 50 },
		},
	}))
end

function Skill:Activate()
	self.Target = nil

	const CombatService = Crane:GetService("CombatService")

	-- One layer spans the search, telegraph and strike. It is released by the
	-- strike cleaner, or by hand below when no target is found (Interrupt is
	-- not called when the bind is simply released).
	self.CastSlow = self.Character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Medium)
	self.CastNoJump = self.Character:AddParameter("MaxJumpPower", 0)
	self.StrikeSequence.Cleaner:Add(self.CastSlow)
	self.StrikeSequence.Cleaner:Add(self.CastNoJump)

	-- Any committed cast spends the cooldown, whether the hitbox connects or
	-- not. The engine no longer overwrites it with Cooldown = 0 on return.
	self:SetCooldown(20)

	const targets = CombatService:Hitbox({
		Caster = self.Character,
		Info = {
			Size = self.Data.SearchRadius,
			SortByDistance = true,
		},
	}) :: { types.Character }
	self.Target = targets[1]
	if not self.Target then
		self.CastSlow:Destroy()
		self.CastNoJump:Destroy()
		return
	end

	if self.TelegraphSequence then
		self.TelegraphSequence:Play()
		self.TelegraphSequence:Await()
	end

	-- A strike interrupted during the telegraph never starts; Await() would
	-- hang forever on a sequence stuck in the None state.
	if self.StrikeSequence and self.StrikeSequence:IsPlaying() then self.StrikeSequence:Await() end
end

function Skill:Interrupt()
	if self.TelegraphSequence then self.TelegraphSequence:Stop() end
	if self.StrikeSequence then
		self.StrikeSequence:Stop()
		self.StrikeSequence.Cleaner:Clean()
	end
end

return Skill
