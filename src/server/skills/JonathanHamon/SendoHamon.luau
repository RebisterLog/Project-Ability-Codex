const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Sendo Hamon",
	Cooldown = 2,
	BaseSpec = "JonathanHamon",
	SkillCharacters = {"Hit"},

	AttackInfo = {
		Hitbox = {
			Size = Vector3.new(30, 2, 30),
			Offset = CFrame.new(0, -3, 0),
			Debug = true,
		},

		Damage = 0.25,

		Block = {
			Blockable = true,
			PerfectBlockable = false,
			BlockBreak = false,
		},

		Stun = {
			Priority = Enums.Stun.Medium,
			Duration = 0.5,
		},
	},

	ReleaseInfo = {
		Damage = 2,
		
		Ragdoll = {
			Duration = Enums.Ragdoll.Heavy,
		},
	}
}

function Skill.onInit(self)
	const character = self.Character
	const RootPart = character.RootPart
	const Humanoid = character.Humanoid
	const VFXService = Crane:GetService("VFXService")

	const CombatService = Crane:GetService("CombatService")

	const AttackInfo = self.Data.AttackInfo
	const ReleaseInfo = self.Data.ReleaseInfo

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Slowed))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = character.instance,
						Animation = self:GetAsset("Animations/SendoHamon"),
						Speed = seq.Speed,
					})
					--
					-- 					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
					-- 						Origin = RootPart,
					-- 						Sound = self:GetAsset("Sounds/NAME"),
					-- 					})

				end,
			},

			{
				20,
				function(seq, frame)
					if frame % 10 ~= 0 then return end

					local Targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = AttackInfo.Hitbox,
					})

					for _, Target in Targets do
						CombatService:Attack({
							Attacker = character,
							Victim = Target,
							Info = AttackInfo,
						})
					end
				end,
				120,
			},

			{
				125,
				function(seq)
					local Targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = AttackInfo.Hitbox
					})

					for _, Target in Targets do
						CombatService:Attack({
							Attacker = character,
							Victim = Target,
							Info = ReleaseInfo,
						})
					end
				end,
			},

			{ 130 },
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
	
	VFXService:StopEffect(Players:GetPlayers(), "Animation", { Character = character.instance,
		Animation = self:GetAsset("Animations/SendoHamon").Animation,
	})
end

return Skill
