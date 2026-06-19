local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)
local Proxy = require(ReplicatedStorage.shared.packages.Proxy)
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Enums = require(ServerScriptService.server.Enums)
local types = require(ServerScriptService.server.types)

local Skill: types.SkillData = {
	DisplayName = "Punch",
	ComboCooldown = 1.5,
	ComboResetTime = 1.5,
	MaxCombo = 4,
	
	SkillCharacters = {
		"Hit",
		"Stun",
		"ComboStarter",
		"Blockable",
	},
}

function Skill:onInit()
	local character = self.Character :: types.Character
	local RootPart = character.RootPart
	local Humanoid = character.Humanoid
	local VFXService = Crane:GetService("VFXService")
	
	local CombatService = Crane:GetService("CombatService")
	
	local Anims = self.Spec.Data.Assets.Animations
	local Sounds = self.Spec.Data.Assets.Sounds
	local Models = self.Spec.Data.Assets.Models
	
	self.PunchCount = 1
	self.AlreadyHit = {}
	
	self.Sequence = self.Janitor:Add(CombatService.CreateSequence(character, {
		Frames = {
			{0, function(seq)
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 8))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))
					
					table.clear(self.AlreadyHit)
					
					if self.PunchCount > 1 then
						VFXService:StopEffect(Players:GetPlayers(), "Animation", character.instance, {
							Animation = Anims["Punch"..self.PunchCount - 1].Animation,
						})
					end
					
					VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, {
						Animation = Anims["Punch"..self.PunchCount],
						Speed = seq.Speed, 
					})
					
					VFXService:StartEffect(Players:GetPlayers(), "Sound", RootPart, Sounds[`Punch{self.PunchCount}`])
					
					for i, trail: Trail in character.instance:QueryDescendants("Trail") do
						if trail.Name ~= "PunchTrail" then continue end
						trail.Enabled = true
					end
					
					seq.Cleaner:Add(function()
						for i, trail: Trail in character.instance:QueryDescendants("Trail") do
							if trail.Name ~= "PunchTrail" then continue end
							trail.Enabled = false
						end
					end)
				end,},
			
			{15,function(seq, Frame)
					local Targets = CombatService:Hitbox({
						Skill = self,
						Caster = character,
						Info = {
							Size = Vector3.new(7,7,7),
							Offset = CFrame.new(0,0,-3),
							Debug = true, 
						}
					}) :: {types.Character}
					
					for _, Target in Targets do
						if table.find(self.AlreadyHit, Target) then
							continue
						end
						
						CombatService:Attack({
							Attacker = character,
							Victim = Target,
							Info = {
								Damage = 2.5,
								Block ={
									PerfectBlockable = false,
									--BlockCancel = self.PunchCount == self.Data.MaxCombo
								},
								Knockback = {
									RelativePart = self.PunchCount == self.Data.MaxCombo and "Attacker", 
									ToFront = if self.PunchCount ~= self.Data.MaxCombo then 5 else false,
									Speed = self.PunchCount == self.Data.MaxCombo and 200 or 8, 
									Duration = self.PunchCount == self.Data.MaxCombo and 0.05 or 0.05,
								}, 
								Stun = {
									Priority = Enums.Stun.Medium,
									Duration = 0.35,
								}
							}
						}):andThen(function(data)
							if data.State.Success then
								table.insert(self.AlreadyHit, Target)
								
								if not data.State.Blocked then
									VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", {
										Particle = Models["PunchHit"],
										Origin = Target.RootPart
									})
								end
							end
						end)
					end
				end,
			30},
		}
	}))
end


function Skill:Activate()
	if self.Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end
	
	self.PunchCount += 1
	if self.PunchCount > self.Data.MaxCombo then
		self.PunchCount = 1
		self:SetCooldown(self.Data.ComboCooldown)
	elseif self.Data.ComboResetTime then
		local oldCount = self.PunchCount
		task.delay(self.Data.ComboResetTime, function()
			if oldCount == self.PunchCount then
				self.PunchCount = 1
			end
		end)
	end
end

function Skill:Interrupt()
	local PunchCount = self.PunchCount
	
	if self.Sequence then
		self.Sequence:Stop()
	end
	
	local Anims = self.Spec.Data.Assets.Animations
	local VFXService = Crane:GetService("VFXService")
	VFXService:StopEffect(Players:GetPlayers(), "Animation", self.Character.instance, {
		Animation = Anims["Punch"..PunchCount].Animation,
	})
end

return Skill