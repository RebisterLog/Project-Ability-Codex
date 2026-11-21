--[=[ SILVER_PIERCE

   Single thrust of the Hamon sword. The sword is equipped for the skill only:
   the cleaner removes the clone (and its Motor6D) on hit, interrupt or death.

   ASSETS:

   Animations
      SilverPierce : Thrust animation (assets/JonathanHamon).

   Sounds
      SilverPierce : Thrust sound (assets/JonathanHamon).

   Models
      Sword : Equipped through CombatService:Equip for the skill duration.

]=]

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "Silver Pierce",
	Cooldown = 8,
	BaseSpec = "JonathanHamon",
	SkillCharacters = {
		"Hit",
		"Blockable",
		"Stun",
	},

	AttackInfo = {
		Hitbox = {
			Size = Vector3.new(3, 3, 10),
			Offset = CFrame.new(0, 0, -5),
			Debug = true,
		},

		Damage = 5,

		Block = {
			Blockable = true,
			PerfectBlockable = false,
			BlockBreak = false,
		},

		Stun = {
			Priority = Enums.Stun.Medium,
			Duration = Enums.StunTime.Medium,
		},
	},
}

function Skill.onInit(self)
	const character = self.Character
	const RootPart = character.RootPart
	const VFXService = Crane:GetService("VFXService")
	const CombatService = Crane:GetService("CombatService")

	const AttackInfo = self.Data.AttackInfo

	self.AlreadyHit = {}

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					table.clear(self.AlreadyHit)

					const Sword = CombatService:Equip(character, self:GetAsset("Models/Sword"))
					seq.Cleaner:Add(Sword)

					const anim = self:GetAsset("Animations/SilverPierce")
					VFXService:StartEffect(Players:GetPlayers(), "Animation", {
						Character = character.instance,
						Animation = anim,
						Speed = seq.Speed,
					})

					VFXService:StartEffect(Players:GetPlayers(), "Sound", {
						Origin = RootPart,
						Sound = self:GetAsset("Sounds/SilverPierce"),
					})
				end,
			},

			{
				25,
				function()
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
						end)
					end
				end,
				30,
			},

			{ 30 },
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
	if self.Sequence then self.Sequence:Stop() end

	VFXService:StopEffect(Players:GetPlayers(), "Animation", {
		Character = character.instance,
		Animation = anim.Animation,
	})
end

return Skill
