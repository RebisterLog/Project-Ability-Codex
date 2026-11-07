const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Ground Slam",
	Cooldown = 20,
	Tag = "OnlyForStand",

	SkillCharacters = {
		"Hit",
		"Ragdoll",
		"IgnoreBlock",
		"ComboEnder",
		"Armored",
	},

	AttackInfo = {
		Hitbox = {
			Size = 10,
			Offset = CFrame.new(0, -4, -5),
			Debug = true,
		},

		Damage = 15,

		Block = {
			BlockIgnore = true,
			Blockable = false,
			PerfectBlockable = false,
		},

		Ragdoll = {
			Duration = Enums.Ragdoll.Light,
		},

		Knockback = {
			Duration = 0.1,
			Velocity = Vector3.new(0, 50, 0),
			Speed = 30,
			RelativePart = "Attacker",
		},
	},
}

function Skill.onInit(self)
	const character = self.Character
	const RootPart = character.RootPart
	const Humanoid = character.Humanoid
	const VFXService = Crane:GetService("VFXService")

	const CombatService = Crane:GetService("CombatService")

	const Anims = self.Spec.Data.Assets.Stand.Animations
	const Sounds = self.Spec.Data.Assets.Stand.Sounds
	const Models = self.Spec.Data.Assets.Stand.Models
	const AttackInfo = self.Data.AttackInfo

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					seq.Cleaner:Add(CombatService:AddArmor(character, true))
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", Enums.CastSpeed.Slowed))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					VFXService:StartEffect(Players:GetPlayers(), "Animation", { Character = self.Stand.instance, 
						Animation = Anims["GroundSlam"],
						Speed = seq.Speed,
					})

					VFXService:StartEffect(Players:GetPlayers(), "Sound", { Origin = self.Stand.RootPart, Sound = Sounds["GroundSlam"] })

					seq.Cleaner:Add(function()
						VFXService:StopEffect(Players:GetPlayers(), "Animation", { Character = self.Stand.instance, 
							Animation = Anims["GroundSlam"].Animation,
						})
					end)
				end,
			},

			{
				40,
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
							Info = AttackInfo,
						}):andThen(function(Data: types.AttackData)
							if not Data.State.Success then return end

						end)
					end
				end,
			},

			{ 55 },
		},
	}))
end

function Skill.Activate(self)
	const StandService = Crane:GetService("StandService")
	const stand = StandService:GetStand(self.Character) :: types.Stand

	self.Stand = stand

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

	const Sounds = self.Spec.Data.Assets.Stand.Sounds

	VFXService:StopEffect(Players:GetPlayers(), "Sound", { Origin = self.Stand.RootPart, Sound = Sounds["GroundSlam"].Sound })
end

return Skill
