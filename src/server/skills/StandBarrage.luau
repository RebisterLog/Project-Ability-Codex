const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Barrage",
	Cooldown = 2,

	Tag = "OnlyForStand",

	SkillCharacters = {
		"Hit",
		"ComboExtender",
		"Blockable",
	},

	BarrageInfo = {
		Hitbox = {
			Size = Vector3.new(6, 6, 8),
			Offset = CFrame.new(0, 0, -4),
			MovementCorrection = true,
			Debug = true,
		},

		Damage = 0.1,

		Block = {
			Blockable = true,
			PerfectBlockable = false,
			BlockBreak = false,
			BlockCancel = false,
			BlockIgnore = false,
		},

		Stun = {
			Priority = Enums.Stun.Heavy,
			Duration = Enums.StunTime.ExtraLight,
		},

		Knockback = {
			Direction = {
				Mode = "AwayFromAttacker",
				Add = { { Mode = "ToFront", Distance = 5 } },
			},
			Push = 6,
			Lift = 0,
			Hold = 0.05,
		},

		HitAnimations = "Default",

		HitEffects = { {
			Particle = "Models/BarrageHit",
			Sound = "Default",
		} },
	} :: types.AttackInfo,

	PostBarrageInfo = {
		Hitbox = {
			Size = Vector3.new(6, 6, 10),
			Offset = CFrame.new(0, 0, -6),
			Debug = true,
		},

		Damage = 10,

		Block = {
			Blockable = false,
			PerfectBlockable = false,
			BlockBreak = false,
			BlockCancel = true,
			BlockIgnore = false,
		},

		Stun = {
			Priority = Enums.Stun.Medium,
			Duration = 0.1,
		},

		Knockback = {
			Direction = { Mode = "AwayFromAttacker" },
			Push = 100,
			Hold = 0.25,
			MaxForce = Vector3.new(100_000, 0, 100_000),
		},

		HitAnimations = "Default",

		HitEffects = { {
			Particle = "Models/BarrageHeavyHit",
			Sound = "Default",
		} },
	},
}

function Skill.onInit(self)
	const character = self.Character
	const RootPart = character.RootPart
	const VFXService = Crane:GetService("VFXService")
	const CombatService = Crane:GetService("CombatService")

	local barrageAnim = self:GetAsset("Stand/Animations/Barrage")
	local barrageSound = self:GetAsset("Stand/Sounds/Barrage")
	local barrageHitSound = self:GetAsset("Stand/Sounds/BarrageHit")

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 12))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = self.Caster.instance,
						Animation = barrageAnim,
						Speed = seq.Speed,
					})
					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = RootPart,
						Sound = barrageSound,
						Speed = seq.Speed,
					})

					self.BarrageUUID = os.clock()

					--VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", {
					--	UUID = self.BarrageUUID,
					--	Particle = self:GetAsset("Stand/Models/Barrage"),
					--	Origin = character.RootPart,
					--})

					seq.Cleaner:Add(function()
						VFXService:StopEffect(Players:GetPlayers(), "Animation", {
							Character = self.Caster.instance,
							Animation = barrageAnim.Animation,
						})

						VFXService:StopEffect(Players:GetPlayers(), "Barrage", {
							UUID = self.BarrageUUID,
						})
						VFXService:StopEffect(Players:GetPlayers(), "Sound", {
							Origin = RootPart,
							Sound = barrageSound.Sound,
						})
					end)
				end,
			},

			{
				4,
				function()
					VFXService:StartEffect(Players:GetPlayers(), "Barrage", {
						Character = self.Caster.instance,
						Type = "Arm",
						Rate = 120,
						Lifetime = 0.3,
						UUID = self.BarrageUUID,
					})
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
							Victim = target,
							Info = self.Data.BarrageInfo,
						})
					end
				end,
				170,
				Interval = 4,
			},

			{
				171,
				function()
					VFXService:StopEffect(Players:GetPlayers(), "Barrage", {
						UUID = self.BarrageUUID,
					})
					VFXService:StopEffect(Players:GetPlayers(), "Sound", {
						Origin = RootPart,
						Sound = barrageSound.Sound,
					})
				end,
			},

			{
				173,
				function(seq)
					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = RootPart,
						Sound = barrageHitSound,
						Speed = seq.Speed,
					})
				end,
			},

			{
				180,
				function()
					const targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = self.Data.PostBarrageInfo.Hitbox,
					})

					for i, target in targets do
						CombatService:Attack({
							Skill = self,
							Victim = target,
							Info = self.Data.PostBarrageInfo,
						})
					end
				end,
			},

			{ 190 },
		},
	}) :: Sequencer.Sequencer)
end

function Skill.Activate(self: types.Skill)
	if self.Sequence then
		const StandService = Crane:GetService("StandService")

		const stand = StandService:GetStand(self.Character) :: types.Stand
		const isStandActive = if stand then stand:IsActive() else false

		self.Caster = stand

		self.Sequence.Cleaner:Add(self.Deactivated:Once(function()
			if self.Sequence.CurrentFrame <= 160 then self.Sequence:Stop() end
		end))

		self.Sequence:Play()
		self.Sequence:Await()
	end
end

function Skill.Interrupt(self)
	if self.Sequence then self.Sequence:Stop() end
end

return Skill
