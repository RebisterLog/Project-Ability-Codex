--!native
--!optimize 2

--[=[ WaitALittleBit

   Big circular sweep attack centered on the caster. Grants hyper armor during the wind-up
   and hits all enemies in a large radius around the caster. Breaks blocking enemies but can
   be perfect blocked.


   ASSETS:

   Animations
      WaitALittleBit : Animation for the sweep

   Sounds
      WaitALittleBit : Sound for the cast
      WaitALittleBitHit : Sound for hit connect
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Enums = require(ServerScriptService.server.Enums)
local types = require(ServerScriptService.server.types)

local Skill: types.SkillData = {
	DisplayName = "Wait A Little Bit",
	Cooldown = 4,

	SkillCharacters = {
		"Hit",
		"ComboEnder",
		"PerfectBlockable",
		"Armored",
		"BlockBreaker",
		"Blockable",
		"Ragdoll",
	},

	AttackInfo = {
		Priority = Enums.IFrames.Ragdoll,

		Hitbox = {
			Size = 10,
			Offset = CFrame.new(0, 0, 0),
			Debug = true,
		},

		Damage = 15,

		Block = {
			PerfectBlockable = true,
			BlockBreak = true,
		},

		Ragdoll = {
			Duration = 1.5,
		},

		Knockback = {
			RelativePart = "Attacker",
			Speed = 40,
			Duration = 0.1,
			Velocity = Vector3.new(0, 20, 0),
		},
	},
}

function Skill:onInit()
	local character = self.Character :: types.Character
	local RootPart = character.RootPart
	local VFXService = Crane:GetService("VFXService")
	local CombatService = Crane:GetService("CombatService")

	local Anims = self.Spec.Data.Assets.Animations
	local Sounds = self.Spec.Data.Assets.Sounds
	local AttackInfo = self.Data.AttackInfo

	self.AlreadyHit = {}

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					seq.Cleaner:Set("Armor", CombatService:AddArmor(character, true))
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 3))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					table.clear(self.AlreadyHit)

					VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, {
						Animation = Anims["WaitALittleBit"],
						Speed = seq.Speed,
					})

					VFXService:StartEffect(
						Players:GetPlayers(),
						"Sound",
						RootPart,
						Sounds["WaitALittleBit"]
					)

					seq.Cleaner:Add(function()
						VFXService:StopEffect(
							Players:GetPlayers(),
							"Animation",
							character.instance,
							{
								Animation = Anims["WaitALittleBit"].Animation,
							}
						)
					end)
				end,
			},

			{
				75,
				function(seq)
					local Targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = AttackInfo.Hitbox,
					}) :: { types.Character }

					for _, Target in Targets do
						if table.find(self.AlreadyHit, Target) then continue end

						CombatService:Attack({
							Attacker = character,
							Victim = Target,
							Info = AttackInfo,
						}):andThen(function(Data: types.AttackData)
							if not Data.State.Success then return end
							table.insert(self.AlreadyHit, Target)

							VFXService:StartEffect(
								Players:GetPlayers(),
								"Sound",
								Target.RootPart,
								Sounds["WaitALittleBitHit"]
							)
						end)
					end
				end,
				80,
			},

			{
				125,
				function(seq)
					seq.Cleaner:Remove("Armor")
				end,
			},

			{ 130 },
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
	local VFXService = Crane:GetService("VFXService")

	local Anims = self.Spec.Data.Assets.Animations

	if self.Sequence then self.Sequence:Stop() end

	VFXService:StopEffect(Players:GetPlayers(), "Animation", self.Character.instance, {
		Animation = Anims["WaitALittleBit"].Animation,
	})
end

return Skill
