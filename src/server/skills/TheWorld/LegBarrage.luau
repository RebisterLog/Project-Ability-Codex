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
			Size = Vector3.new(5, 5, 10),
			Offset = CFrame.new(0, 0, -6),
			MovementCorrection = true,
			Debug = true,
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
			PerfectBlockable = true,
			BlockBreak = true,
			BlockCancel = false,
			BlockIgnore = false,
		},
		Ragdoll = {
			Duration = Enums.Ragdoll.Light,
		},
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

					self.BarrageUUID = os.clock()

					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Medium))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = stand.instance,
						Animation = self:GetAsset("Stand/Animations/LegBarrage"),
						Speed = seq.Speed,
					})
					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = stand.RootPart,
						Sound = self:GetAsset("Stand/Sounds/LegBarrage"),
						Speed = seq.Speed,
					})

					seq.Cleaner:Add(function()
						VFXService:StopEffect(Players:GetPlayers(), "Animation", {
							Character = stand.instance,
							Animation = self:GetAsset("Stand/Animations/LegBarrage").Animation,
						})
						VFXService:StopEffect(Players:GetPlayers(), "Barrage", {
							UUID = self.BarrageUUID,
						})
						VFXService:StopEffect(Players:GetPlayers(), "Sound", {
							Origin = stand.RootPart,
							Sound = self:GetAsset("Stand/Sounds/LegBarrage").Sound,
						})
					end)
				end,
			},

			{
				36,
				function()
					VFXService:StartEffect(Players:GetPlayers(), "Barrage", {
						Character = self.Stand.instance,
						Type = "Leg",
						Rate = 120,
						Lifetime = 0.3,
						UUID = self.BarrageUUID,
					})
				end,
			},

			{
				40,
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
				110,
				Interval = 4,
			},

			{
				112,
				function()
					VFXService:StopEffect(Players:GetPlayers(), "Barrage", {
						UUID = self.BarrageUUID,
					})
				end,
			},

			{
				128,
				function(seq)
					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = self.Stand.RootPart,
						Sound = self:GetAsset("Stand/Sounds/LegBarrageHit"),
						Speed = seq.Speed,
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

			{ 135 },
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
