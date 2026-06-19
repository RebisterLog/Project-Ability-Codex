local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local types = require(ServerScriptService.server.types)
local Enums = require(ServerScriptService.server.Enums)
local Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)

local Skill: types.SkillData = {
	DisplayName = "Barrage",
	Cooldown = 2,
	
	SkillCharacters = {
		"Hit",
		"ComboExtender",
		"Blockable"
	},
	
	PreBarrageInfo = {
		Hitbox = {
			Size = Vector3.new(6,6,6),
			Offset = CFrame.new(0,0,-3),
			Debug = true,
		},

		Damage = 2.5,

		Block = {
			Blockable = true,
			PerfectBlockable = false,
			BlockBreaker = false,
		},

		Stun = {
			Priority = Enums.Stun.Medium,
			Duration = 0.5,
		},
	},
	
	BarrageInfo = {
		Hitbox = {
			Size = 8,
			Offset = CFrame.new(0,0,0),
			Debug = true,
		},

		Damage = 0.1,

		Block = {
			Blockable = true,
			PerfectBlockable = false,
			BlockBreaker = false,
		},

		Stun = {
			Priority = Enums.Stun.Heavy,
			Duration = 0.5,
		},
		
		Knockback = {
			RelativePart = "Attacker",
			ToFront = 2,
			Speed = 6,
			Duration = 0.05,
			Vector3.new(0, 0.75, 0)
		},
	} :: types.AttackInfo,
	
	PostBarrageInfo = {
		Hitbox = {
			Size = Vector3.new(6,6,10),
			Offset = CFrame.new(0,0,-5),
			Debug = true,
		},

		Damage = 10,

		Block = {
			BlockCancel = true,
			PerfectBlockable = false,
			BlockBreaker = false,
		},
		
		Stun = {
			Priority = Enums.Stun.Medium,
			Duration = 0.1
		},
		
		Knockback = {
			RelativePart = "Attacker",
			Speed = 100,
			Duration = 0.25,
		},
	}
}

function Skill.onInit(self)
	local character = self.Character
	local RootPart = character.RootPart
	local VFXService = Crane:GetService("VFXService")
	local CombatService = Crane:GetService("CombatService")
	
	local Anims = self.Spec.Data.Assets.Animations
	local Sounds = self.Spec.Data.Assets.Sounds
	local Models = self.Spec.Data.Assets.Models
	
	self.Sequence = CombatService.CreateSequence(character, {
		Frames = {
			{0, function(seq)
				seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 12))
				seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))
				
				VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, {
					Animation = Anims["Barrage"],
					Speed = seq.Speed, 
				})
				
				self.BarrageUUID = os.clock()

				VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", {
					UUID = self.BarrageUUID,
					Particle = Models["Barrage"],
					Origin = character.RootPart,
				})

				seq.Cleaner:Add(function()
					VFXService:StopEffect(Players:GetPlayers(), "Animation", character.instance, {
						Animation = Anims["Barrage"].Animation,
					})
					
					VFXService:StopEffect(Players:GetPlayers(), "EmitParticle", self.BarrageUUID)
					VFXService:StopEffect(Players:GetPlayers(), "Sound", RootPart, Sounds["Barrage"].Sound)
				end)
			end,},
			
			{15, function()
				VFXService:StartEffect(Players:GetPlayers(), "Sound", RootPart, Sounds["PreBarrage"])

				local targets = CombatService:Hitbox({
					Caster = character,
					Skill = self,
					Info = self.Data.PreBarrageInfo.Hitbox,
				})

				for i, target in targets do
					CombatService:Attack{
						Attacker = character,
						Victim = target,
						Info = self.Data.PreBarrageInfo,
					}
				end
			end,},
			
			{30, function()
				VFXService:StartEffect(Players:GetPlayers(), "Sound", RootPart, Sounds["PreBarrage"])

				local targets = CombatService:Hitbox({
					Caster = character,
					Info = self.Data.PreBarrageInfo.Hitbox,
				})

				for i, target in targets do
					CombatService:Attack{
						Attacker = character,
						Victim = target,
						Info = self.Data.PreBarrageInfo,
					}
				end
			end,},
			
			{44, function(seq)
				VFXService:StartEffect(Players:GetPlayers(), "Sound", RootPart, Sounds["Barrage"])

				seq.Cleaner:Add(function()
					VFXService:StopEffect(Players:GetPlayers(), "Sound", RootPart, Sounds["Barrage"].Sound)
				end)
			end,},
			
			{45, function(seq, frame)
				if frame % 4 ~= 0 then return end

				local targets = CombatService:Hitbox({
					Skill = self,
					Caster = character,
					Info = self.Data.BarrageInfo.Hitbox,
				})
				
				for i, target in targets do
					CombatService:Attack{
						Attacker = character,
						Victim = target,
						Info = self.Data.BarrageInfo,
					}
				end
			end,
			190},
			
			{191,function()
				VFXService:StopEffect(Players:GetPlayers(), "EmitParticle", self.BarrageUUID)
			end,},
			
			{205, function()
				local targets = CombatService:Hitbox({
					Skill = self,
					Caster = character,
					Info = self.Data.PostBarrageInfo.Hitbox,
				})

				for i, target in targets do
					CombatService:Attack{
						Attacker = character,
						Victim = target,
						Info = self.Data.PostBarrageInfo,
					}
				end
			end,},
			
			{235},
		}
	}) :: Sequencer.Sequencer
end

function Skill.Activate(self: types.Skill)
	if self.Sequence then
		self.Sequence:Play()

		self.Sequence.Cleaner:Add(self.Deactivated:Once(function()
			if self.Sequence.CurrentFrame <= 160 then
				self.Sequence:Stop()
			end
		end))
		
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
	--VFXService:StopEffect(Players:GetPlayers(), "Sound", RootPart, Sounds[self.GrabData.Prefix.."Grab"])
	--VFXService:StopEffect(Players:GetPlayers(), "Sound", RootPart, Sounds[self.GrabData.Prefix.."GrabVL"])
end

return Skill