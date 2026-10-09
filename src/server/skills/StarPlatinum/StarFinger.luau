local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Enums = require(ServerScriptService.server.Enums)
local Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)
local types = require(ServerScriptService.server.types)

local Skill: types.SkillData = {
	DisplayName = "Star Finger",
	Cooldown = 5,

	SkillCharacters = {
		"Hit",
		"ComboExtender",
		"Blockable",
	},

	Tag = "OnlyForStand",

	AttackInfo = {
		Hitbox = {
			Size = Vector3.new(7, 7, 7),
			Offset = CFrame.new(0, 0, -3),
			Debug = true,
		},

		Damage = 10,

		Block = {
			Blockable = true,
			PerfectBlockable = false,
			BlockBreak = false,
		},

		Stun = {
			Priority = Enums.Stun.Medium,
			Duration = 1,
		},
	},
}

function Skill.onInit(self)
	local character = self.Character
	local RootPart = character.RootPart
	local Humanoid = character.Humanoid
	local VFXService = Crane:GetService("VFXService")

	local CombatService = Crane:GetService("CombatService")

	local Anims = self.Spec.Data.Assets.Animations
	local Sounds = self.Spec.Data.Assets.Sounds
	local Models = self.Spec.Data.Assets.Models
	local AttackInfo = self.Data.AttackInfo

	self.AlreadyHit = {}

	self.Sequence = self.Janitor:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 8))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

					table.clear(self.AlreadyHit)

					VFXService:StartEffect(Players:GetPlayers(), "Animation", self.Caster.instance, {
						Animation = Anims["StarFinger"],
						Speed = seq.Speed,
					})

					VFXService:StartEffect(Players:GetPlayers(), "Sound", RootPart, Sounds["StarFinger"])

					seq.Cleaner:Add(function()
						VFXService:StopEffect(Players:GetPlayers(), "Animation", self.Caster.instance, {
							Animation = Anims["StarFinger"].Animation,
						})
					end)
				end,
			},

			{
				15,
				function(seq)
					local Targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = AttackInfo.Hitbox
					})

					for _, Target in Targets do
						if table.find(self.AlreadyHit, Target) then
							continue
						end

						CombatService:Attack({
							Attacker = character,
							Victim = Target,
							Info = AttackInfo,
						}):andThen(function(Data: types.AttackData)
							if not Data.State.Success then return end
							table.insert(self.AlreadyHit, Target)

							-- VFX for target
						end)
					end
				end,
				30,
			},

			{ 45 },
		},
	}))
end

function Skill.Activate(self)
    if self.Sequence then
		local StandService = Crane:GetService("StandService")

		local stand = StandService:GetStand(self.Character) :: types.Stand
		local isStandActive = if stand then stand:IsActive() else false

		self.Caster = stand

		self.Sequence:Play()
		self.Sequence:Await()
	end
end

function Skill.Interrupt(self)
	local character = self.Character
	local RootPart = character.RootPart
	local VFXService = Crane:GetService("VFXService")

	if self.Sequence then self.Sequence:Stop() end
end

return Skill
