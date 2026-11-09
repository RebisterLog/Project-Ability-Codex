const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Silver Pierce",
	Cooldown = 2,
	BaseSpec = "JonathanHamon",

	AttackInfo = {
		Hitbox = {
			Size = Vector3.new(7, 7, 7),
			Offset = CFrame.new(0, 0, -3),
			Debug = true,
		},

		Damage = 15,

		Block = {
			Blockable = true,
			PerfectBlockable = false,
			BlockBreak = false,
		},

		Stun = {
			Priority = Enums.Stun.Medium,
			Duration = 0.7,
		},

		Ragdoll = {
			Duration = 2,
		},

		Knockback = {
			RelativePart = "Attacker",
			Duration = 0.1,
			Velocity = Vector3.new(0, 50, 0),
			Speed = 40,
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
					--seq.Cleaner:Add(CombatService:AddArmor(character, true))
					--seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 3))
					--seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					--table.clear(self.AlreadyHit)

					--VFXService:StartEffect(Players:GetPlayers(), "Animation", { Character = character.instance,
					--	Animation = Anims["NAME"],
					--	Speed = seq.Speed,
					--})

					--VFXService:StartEffect(Players:GetPlayers(), "Sound", { Origin = RootPart, Sound = Sounds["NAME"] })

					--seq.Cleaner:Add(function()
					--	VFXService:StopEffect(Players:GetPlayers(), "Animation", { Character = character.instance,
					--		Animation = Anims["NAME"].Animation,
					--	})
					--end)
				end,
			},

			{
				30,
				function(seq)
					--local Targets = CombatService:Hitbox({
					--	Skill = self,
					--	Caster = character,
					--	Info = AttackInfo.Hitbox
					--})

					--for _, Target in Targets do
					--	if table.find(self.AlreadyHit, Target) then
					--		continue
					--	end

					--	CombatService:Attack({
					--		Attacker = character,
					--		Victim = Target,
					--		Info = AttackInfo,
					--	}):andThen(function(Data: types.AttackData)
					--		if not Data.State.Success then return end
					--		table.insert(self.AlreadyHit, Target)

					--	end)
					--end
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
	const RootPart = character.RootPart
	const VFXService = Crane:GetService("VFXService")

	if self.Sequence then self.Sequence:Stop() end
end

return Skill
