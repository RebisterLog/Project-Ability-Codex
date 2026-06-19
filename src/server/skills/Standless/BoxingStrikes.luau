--[=[ BoxingStrikes

	A 3-hit boxing combo with caster slowdown. Each hit has a different combat
	role: first is perfect-blockable, second is a block breaker, third is a
	block-breaking ragdoll finisher. All hits deal equal damage.


	ASSETS:

	Animations
		BoxingStrikes : Animation for the full combo sequence

	Sounds
		BoxingStrikesVL : Voice line / swing sound
		BoxingStrikesHit : Hit impact sound
]=]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local types = require(ServerScriptService.server.types)
local Enums = require(ServerScriptService.server.Enums)

local Skill: types.SkillData = {
	DisplayName = "Boxing Strikes",
	Cooldown = 3,

	SkillCharacters = {
		"Hit",
		"ComboEnder",
		"BlockBreaker",
		"PerfectBlockable",
	},

	Hit1Info = {
		Hitbox = {
			Size = Vector3.new(7, 7, 7),
			Offset = CFrame.new(0, 0, -3),
			Debug = true,
		},

		Damage = 15,

		Block = {
			Blockable = true,
			PerfectBlockable = true,
		},

		Stun = {
			Priority = Enums.Stun.Light,
			Duration = 0.4,
		},
	},

	Hit2Info = {
		Hitbox = {
			Size = Vector3.new(7, 7, 7),
			Offset = CFrame.new(0, 0, -3),
			Debug = true,
		},

		Damage = 15,

		Block = {
			Blockable = true,
			BlockBreak = true,
		},

		Stun = {
			Priority = Enums.Stun.Medium,
			Duration = 0.6,
		},
	},

	Hit3Info = {
		Hitbox = {
			Size = Vector3.new(9, 7, 9),
			Offset = CFrame.new(0, 0, -3),
			Debug = true,
		},

		Damage = 15,

		Block = {
			Blockable = true,
			BlockBreak = true,
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

		Angular = {
			Velocity = Vector3.new(-15, 0, 0),
			Duration = 0.2,
		},
	},
}

function Skill.onInit(self)
	local character = self.Character
	local RootPart = character.RootPart
	local VFXService = Crane:GetService("VFXService")
	local CombatService = Crane:GetService("CombatService")

	local Anims = self.Spec.Data.Assets.Animations
	local Sounds = self.Spec.Data.Assets.Sounds

	self.AlreadyHit = {}

	self.Sequence = self.Janitor:Add(CombatService.CreateSequence(character, {
		Frames = {
			{1, function(seq)
				seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 3))
				seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

				table.clear(self.AlreadyHit)

				VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, {
					Animation = Anims["BoxingStrikes"],
					Speed = seq.Speed,
				})
				VFXService:StartEffect(Players:GetPlayers(), "Sound", RootPart, Sounds["BoxingStrikesVL"])

				seq.Cleaner:Add(function()
					VFXService:StopEffect(Players:GetPlayers(), "Animation", character.instance, {
						Animation = Anims["BoxingStrikes"].Animation,
					})
				end)
			end},

			{30, function(seq, Frame)
				--TODO: hit with example
				--[[
				table.clear(self.AlreadyHit)
				local Targets = CombatService:Hitbox({
					Skill = self,
					Caster = character,
					Info = self.Data.Hit1Info.Hitbox,
				})
				for _, Target in Targets do
					if table.find(self.AlreadyHit, Target) then continue end
					CombatService:Attack({
						Attacker = character,
						Victim = Target,
						Info = self.Data.Hit1Info,
					}):andThen(function(Data: types.AttackData)
						if not Data.State.Success then return end
						table.insert(self.AlreadyHit, Target)
						VFXService:StartEffect(Players:GetPlayers(), "Sound", Data.Victim.RootPart.CFrame, Sounds["BoxingStrikesHit"])
					end)
				end
				]]
			end},

			{60, function(seq, Frame)
				--TODO: hit with example
				--[[
				table.clear(self.AlreadyHit)
				local Targets = CombatService:Hitbox({
					Skill = self,
					Caster = character,
					Info = self.Data.Hit2Info.Hitbox,
				})
				for _, Target in Targets do
					if table.find(self.AlreadyHit, Target) then continue end
					CombatService:Attack({
						Attacker = character,
						Victim = Target,
						Info = self.Data.Hit2Info,
					}):andThen(function(Data: types.AttackData)
						if not Data.State.Success then return end
						table.insert(self.AlreadyHit, Target)
						VFXService:StartEffect(Players:GetPlayers(), "Sound", Data.Victim.RootPart.CFrame, Sounds["BoxingStrikesHit"])
					end)
				end
				]]
			end},

			{90, function(seq, Frame)
				--TODO: hit with example
				--[[
				table.clear(self.AlreadyHit)
				local Targets = CombatService:Hitbox({
					Skill = self,
					Caster = character,
					Info = self.Data.Hit3Info.Hitbox,
				})
				for _, Target in Targets do
					if table.find(self.AlreadyHit, Target) then continue end
					CombatService:Attack({
						Attacker = character,
						Victim = Target,
						Info = self.Data.Hit3Info,
					}):andThen(function(Data: types.AttackData)
						if not Data.State.Success then return end
						table.insert(self.AlreadyHit, Target)
						VFXService:StartEffect(Players:GetPlayers(), "Sound", Data.Victim.RootPart.CFrame, Sounds["BoxingStrikesHit"])
					end)
				end
				]]
			end},

			{120},
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
	local character = self.Character
	local RootPart = character.RootPart
	local VFXService = Crane:GetService("VFXService")

	local Anims = self.Spec.Data.Assets.Animations
	local Sounds = self.Spec.Data.Assets.Sounds

	if self.Sequence then
		self.Sequence:Stop()
	end

	VFXService:StopEffect(Players:GetPlayers(), "Animation", character.instance, {
		Animation = Anims["BoxingStrikes"].Animation,
	})
	VFXService:StopEffect(Players:GetPlayers(), "Sound", RootPart, Sounds["BoxingStrikesVL"].Sound)
end

return Skill
