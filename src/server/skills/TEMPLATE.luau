local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local types = require(ServerScriptService.server.types)
local Enums = require(ServerScriptService.server.Enums)
local Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)

local Skill: types.SkillData = {
	DisplayName = "NAME",
	Cooldown = 2,

	AttackInfo = {
		Hitbox = {
			Size = Vector3.new(7,7,7),
			Offset = CFrame.new(0,0,-3),
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
			Duration = 0.7
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
			{1, function(seq)
				--seq.Cleaner:Add(CombatService:AddArmor(character, true))
				--seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 3))
				--seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

				--table.clear(self.AlreadyHit)

				--VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, {
				--	Animation = Anims["NAME"],
				--	Speed = seq.Speed, 
				--})
				
				--VFXService:StartEffect(Players:GetPlayers(), "Sound", RootPart, Sounds["NAME"])
				
				--seq.Cleaner:Add(function()
				--	VFXService:StopEffect(Players:GetPlayers(), "Animation", character.instance, {
				--		Animation = Anims["NAME"].Animation,
				--	})					
				--end)
			end,
			},

			{30, function(seq)
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
			35},

			{45}
		}
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

	if self.Sequence then
		self.Sequence:Stop()
	end
end

return Skill