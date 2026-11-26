--[=[
	Leg Barrage

	The stand rains quick leg strikes, then finishes with a guard-breaking
	kick. Same skeleton as StandBarrage but its own clips and VFX.

	ASSETS:
	Animations
	   Stand/Animations/LegBarrage, Stand/Animations/LegBarrageFinisher
	Sounds
	   Stand/Sounds/LegBarrage, LegBarrageHit, LegBarrageVL
	Models
	   Models/LegBarrageVFX, Models/LegBarrageHeavyVFX
]=]

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Leg Barrage",
	Cooldown = 10,
	Tag = "OnlyForStand",

	SkillCharacters = { "Hit", "ComboExtender", "Blockable", "BlockBreaker" },

	BarrageInfo = {
		Hitbox = {
			Size = Vector3.new(6, 6, 8),
			Offset = CFrame.new(0, 0, -4),
			MovementCorrection = true,
		},
		Damage = 0.25,
		Block = {
			Blockable = true,
			PerfectBlockable = false,
			BlockBreak = false,
			BlockCancel = false,
			BlockIgnore = false,
		},
		Stun = { Priority = Enums.Stun.Heavy, Duration = Enums.StunTime.ExtraLight },
		Knockback = {
			Push = 6,
			Lift = 0.75,
			Hold = 0.05,
			Direction = { Mode = "AwayFromAttacker" },
		},
	} :: types.AttackInfo,

	PostBarrageInfo = {
		Hitbox = { Size = Vector3.new(6, 6, 10), Offset = CFrame.new(0, 0, -5) },
		Damage = 10,
		Block = {
			Blockable = false,
			PerfectBlockable = false,
			BlockBreak = true,
			BlockCancel = false,
			BlockIgnore = false,
		},
		Stun = { Priority = Enums.Stun.Medium, Duration = 0.2 },
		Knockback = { Direction = { Mode = "AwayFromAttacker" }, Push = 100, Hold = 0.25 },
		HitEffects = { { Particle = "Models/LegBarrageHeavyVFX", Sound = "Default" } },
	} :: types.AttackInfo,
}

function Skill:onInit()
	const character = self.Character :: types.Character
	const CombatService = Crane:GetService("CombatService")
	const VFXService = Crane:GetService("VFXService")

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					const stand =
						Crane:GetService("StandService"):GetStand(character) :: types.Stand
					self.Stand = stand
					if not stand then return end

					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Medium))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = stand.instance,
						Animation = self:GetAsset("Stand/Animations/LegBarrage"),
						Speed = seq.Speed,
					})
					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = stand.RootPart,
						Sound = self:GetAsset("Stand/Sounds/LegBarrageVL"),
					})
					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = stand.RootPart,
						Sound = self:GetAsset("Stand/Sounds/LegBarrage"),
					})

					self.VFXUUID = os.clock()
					VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", {
						UUID = self.VFXUUID,
						Particle = self:GetAsset("Models/LegBarrageVFX"),
						Origin = stand.RootPart,
					})

					seq.Cleaner:Add(function()
						VFXService:StopEffect(Players:GetPlayers(), "Animation", {
							Character = stand.instance,
							Animation = self:GetAsset("Stand/Animations/LegBarrage").Animation,
						})
						VFXService:StopEffect(
							Players:GetPlayers(),
							"EmitParticle",
							{ UUID = self.VFXUUID }
						)
						VFXService:StopEffect(Players:GetPlayers(), "Sound", {
							Origin = stand.RootPart,
							Sound = self:GetAsset("Stand/Sounds/LegBarrage").Sound,
						})
						VFXService:StopEffect(Players:GetPlayers(), "Sound", {
							Origin = stand.RootPart,
							Sound = self:GetAsset("Stand/Sounds/LegBarrageVL").Sound,
						})
					end)
				end,
			},

			{
				8,
				function()
					const targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = self.Data.BarrageInfo.Hitbox,
					})
					for _, target in targets do
						CombatService:Attack({
							Skill = self,
							Attacker = character,
							Victim = target,
							Info = self.Data.BarrageInfo,
						})
					end
				end,
				84,
				Interval = 4,
			},

			{
				100,
				function()
					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = self.Stand.RootPart,
						Sound = self:GetAsset("Stand/Sounds/LegBarrageHit"),
					})
					const targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = self.Data.PostBarrageInfo.Hitbox,
					})
					for _, target in targets do
						CombatService:Attack({
							Skill = self,
							Attacker = character,
							Victim = target,
							Info = self.Data.PostBarrageInfo,
						})
					end
				end,
			},

			{ 115 },
		},
	}))
end

function Skill:Activate()
	if self.Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end
end

function Skill:Interrupt()
	if self.Sequence then self.Sequence:Stop() end
end

return Skill
