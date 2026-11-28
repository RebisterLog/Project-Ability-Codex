const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const Types = require(ServerScriptService.server.types)

const Skill: Types.SkillData = {
	DisplayName = "Uppercut",
	BaseSpec = "Standless",
	Cooldown = 10,

	SkillCharacters = {
		"Ragdoll",
		"PerfectBlockable",
		"Hit",
		"ComboEnder",
		"Armored",
		"BlockBreaker",
		"Blockable",
	},

	AttackInfo = {
		Hitbox = {
			Size = Vector3.new(7, 7, 7),
			Offset = CFrame.new(0, 0, -3),
			Debug = true,
		},
		--
		Damage = 15,

		Block = {
			Blockable = true,
			PerfectBlockable = true,
			BlockBreak = true,
			BlockCancel = false,
			BlockIgnore = false,
		},

		Knockback = {
			Direction = { Mode = "AwayFromAttacker" },
			Push = 30,
			Lift = 50,
			Hold = 0.1,
		},

		Angular = {
			Velocity = Vector3.new(-15, 0, 0),
			Duration = 0.2,
		},

		Stun = {
			Priority = Enums.Stun.Medium,
			Duration = 0.7,
		},

		Ragdoll = {
			Duration = 2,
		},

		HitEffects = { {
			Particle = "Default",
			Sound = "Sounds/UppercutHit",
		} },
	},
}

function Skill.onInit(self)
	const character = self.Character
	const RootPart = character.RootPart
	const Humanoid = character.Humanoid
	const VFXService = Crane:GetService("VFXService")

	const CombatService = Crane:GetService("CombatService")

	const AttackInfo = self.Data.AttackInfo

	self.AlreadyHit = {}

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				1,
				function(seq)
					seq.Cleaner:Set("Armor", CombatService:AddArmor(character, true))
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 3))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					table.clear(self.AlreadyHit)

					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = character.instance,
						Animation = self:GetAsset("Animations/Uppercut"),
						Speed = seq.Speed,
					})
					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = RootPart,
						Sound = self:GetAsset("Sounds/UppercutVL"),
						Speed = seq.Speed,
					})

					VFXService:StartEffect(Players:GetPlayers(), "EmitFolder", {
						Character = self.Character.instance,
						EffectsFolder = self:GetAsset("Models/UppercutHit"),
					})
				end,
			},

			{
				20,
				function(seq, Frame)
					const Targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = AttackInfo.Hitbox,
					})

					for _, Target in Targets do
						if table.find(self.AlreadyHit, Target) then continue end

						CombatService:Attack({
							Skill = self,
							Victim = Target,
							Info = AttackInfo,
						}):andThen(function(Data)
							if not Data.State.Success then return end

							table.insert(self.AlreadyHit, Target)
						end)
					end
				end,
				24,
			},

			{
				30,
				function(seq)
					seq.Cleaner:Remove("Armor")
				end,
			},

			{ 35 },
		},
	}))
end

function Skill.Activate(self)
	if self.Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end
end

function Skill.Interrupt(self)
	const character = self.Character
	const RootPart = character.RootPart
	const VFXService = Crane:GetService("VFXService")

	if self.Sequence then self.Sequence:Stop() end

	VFXService:StopEffect(Players:GetPlayers(), "Animation", {
		Character = character.instance,
		Animation = self:GetAsset("Animations/Uppercut").Animation,
	})

	VFXService:StopEffect(Players:GetPlayers(), "Sound", {
		Origin = RootPart,
		Sound = self:GetAsset("Sounds/UppercutVL").Sound,
	})
end

return Skill
