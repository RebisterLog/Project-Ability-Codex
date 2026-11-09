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
			BlockBreaker = false,
		},

		Stun = {
			Priority = Enums.Stun.Heavy,
			Duration = 0.5,
		},

		Knockback = {
			RelativePart = "Attacker",
			ToFront = 5,
			Speed = 6,
			Duration = 0.05,
			Velocity = Vector3.new(0, 0.75, 0),
		},
	} :: types.AttackInfo,

	PostBarrageInfo = {
		Hitbox = {
			Size = Vector3.new(6, 6, 10),
			Offset = CFrame.new(0, 0, -6),
			Debug = true,
		},

		Damage = 10,

		Block = {
			BlockCancel = true,
			PerfectBlockable = false,
			BlockBreaker = false,
		},

		Stun = {
			Priority = Enums.Stun.Medium,
			Duration = 0.1,
		},

		Knockback = {
			RelativePart = "Attacker",
			Speed = 100,
			Duration = 0.25,
			MaxForce = Vector3.new(100_000, 0, 100_000),
		},
	},
}

function Skill.onInit(self)
	const character = self.Character
	const RootPart = character.RootPart
	const VFXService = Crane:GetService("VFXService")
	const CombatService = Crane:GetService("CombatService")

	local barrageAnim = self:GetAsset("Stand/Animations/Barrage")
	local barrageSound = self:GetAsset("Stand/Sounds/Barrage")
	local barrageVlSound = self:GetAsset("Stand/Sounds/BarrageVL")
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
						Sound = barrageVlSound,
					})
					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = RootPart,
						Sound = barrageSound,
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
							Sound = barrageVlSound.Sound,
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
				5,
				function(seq, frame)
					if frame % 4 ~= 0 then return end

					const targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = self.Data.BarrageInfo.Hitbox,
					})

					for i, target in targets do
						CombatService:Attack({
							Attacker = character,
							Victim = target,
							Info = self.Data.BarrageInfo,
						})
					end
				end,
				170,
			},

			{
				171,
				function()
					VFXService:StopEffect(Players:GetPlayers(), "Barrage", {
						UUID = self.BarrageUUID,
					})
					VFXService:StopEffect(Players:GetPlayers(), "Sound", {
						Origin = RootPart,
						Sound = barrageVlSound.Sound,
					})
					VFXService:StopEffect(Players:GetPlayers(), "Sound", {
						Origin = RootPart,
						Sound = barrageSound.Sound,
					})
				end,
			},

			{
				173,
				function()
					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = RootPart,
						Sound = barrageHitSound,
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
							Attacker = character,
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
