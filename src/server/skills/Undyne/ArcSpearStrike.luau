const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Arc Spear Strike",
	BaseSpec = "Undyne",
	Cooldown = 2,

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

		Damage = 15,

		Block = {
			Blockable = true,
			PerfectBlockable = true,
			BlockBreak = true,
		},

		Stun = {
			Priority = Enums.Stun.Medium,
			Duration = 0.7,
		},

		Ragdoll = {
			Duration = 2,
		},

		Knockback = {
			Duration = 0.1,
			Velocity = Vector3.new(0, 50, 0),
			Speed = 40,
			RelativePart = "Attacker",
		},

		Angular = {
			Velocity = Vector3.new(-15, 0, 0),
			Duration = 0.2,
		},
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
					seq.Cleaner:Add(CombatService:AddArmor(character, true))
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 3))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					table.clear(self.AlreadyHit)

					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = character.instance,
						Animation = self:GetAsset("Animations/ArcSpearStrike"),
						Speed = seq.Speed,
					})
					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = RootPart,
						Sound = self:GetAsset("Sounds/ArcSpearStrike"),
					})
				end,
			},

			{
				30,
				function(seq, Frame)
					const Targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = AttackInfo.Hitbox,
					})

					for _, Target in Targets do
						if table.find(self.AlreadyHit, Target) then continue end

						CombatService:Attack({
							Attacker = character,
							Victim = Target,
							Info = AttackInfo,
						}):andThen(function(Data: types.AttackData)
							if not Data.State.Success then return end
							table.insert(self.AlreadyHit, Target)

							VFXService:StartEffect(Players:GetPlayers(), "Sound", {
								Origin = Data.Victim.RootPart.CFrame,
								Sound = self:GetAsset("Sounds/ArcSpearStrikeHit"),
							})
						end)
					end
				end,
				35,
			},

			{ 45 },
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
	const VFXService = Crane:GetService("VFXService")

	if self.Sequence then self.Sequence:Stop() end

	VFXService:StopEffect(Players:GetPlayers(), "Animation", {
		Character = character.instance,
		Animation = self:GetAsset("Animations/ArcSpearStrike").Animation,
	})
end

return Skill
