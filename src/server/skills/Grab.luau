local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Types = require(ServerScriptService.server.types)
local Enums = require(ServerScriptService.server.Enums)
local Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)

local Skill: Types.SkillData = {
	DisplayName = "Grab",
	Cooldown = 1,
	
	SkillCharacters = {
		"Grab",
		"ComboEnder",
		"Hit",
		"Ragdoll",
		"IgnoreBlock",
	},
	
	OnGrab = function(self: Types.SkillData, target: Types.Character)
		
	end,
	
	OnThrow = function(self: Types.SkillData, target: Types.Character)
		
	end,

	AttackInfo = {
		Hitbox = {
			Size = Vector3.new(6,6,6),
			Offset = CFrame.new(0,0,-3),
			SortByDistance = true,
			Debug = true,
		},

		Block = {
			PerfectBlockable = false,
			BlockCancel = true
		},
	},
	
	Throw = {
		Priority = Enums.IFrames.Grab,
		Damage = 10,
		
		Block = {
			PerfectBlockable = false,
			BlockCancel = true
		},
		
		Knockback = {
			Duration = 0.1,
			Velocity = Vector3.new(0, 30, 0),
			Speed = 80,
			RelativePart = "Attacker",
			FindCrashObject = true,
		},
		
		Angular = {
			Velocity = Vector3.new(-15,0,0),
			Duration = 0.5,
		},

		Ragdoll = {
			Duration = 1,
		},
		
		Stun = {
			Priority = Enums.Stun.Heavy,
			Duration = 1
		},
	}
}

function Skill.onInit(self)
	local character = self.Character
	local RootPart = character.RootPart
	local Humanoid = character.Humanoid
	local VFXService = Crane:GetService("VFXService")
	
	local CombatService = Crane:GetService("CombatService")

	local Anims = self.Spec.Data.Assets.Animations
	local Sounds = self.Spec.Data.Assets.Sounds
	local AttackInfo = self.Data.AttackInfo
	local ThrowInfo = self.Data.Throw
	
	self.GrabData = {
		Prefix = "StandOff",
		Offset = self.Spec.Data.Assets.Stats.Grab["AnimationOffset"] or CFrame.new(0, 0, -4) * CFrame.Angles(0, 180, 0),
		StartHitFrame = self.Spec.Data.Assets.Stats.Grab["StartHitFrame"] or 30,
		EndHitFrame = self.Spec.Data.Assets.Stats.Grab["EndHitFrame"] or 40,
		FinalFrame = self.Spec.Data.Assets.Stats.Grab["FinalFrame"] or 30,
	}
	
	--AttackInfo.Stun.Duration = self.GrabData.FinalFrame / 60 + 1
	ThrowInfo.Stun.Duration = self.GrabData.FinalFrame / 60

	self.AlreadyHit = {}
	self.Target = nil :: Types.Character?
	
	self.GrabSequence = self.Janitor:Add(CombatService.CreateSequence(character, {
		Validate = function()
			if not self.Target.Parent or not character.instance.Parent then
				return false
			end
			
			return true
		end,
		Frames = {
			{0, function(seq: Sequencer.Sequencer)
				CombatService:Attack{
					Attacker = character,
					Victim = self.Target,
					Info = {
						Block = {
							PerfectBlockable = false,
						},
						
						Stun = {
							Priority = Enums.Stun.Heavy,
							Duration = 2,
						},
					}
				}
				
				seq.Cleaner:Set("GrabObject", CombatService:CreateGrab(character, self.Target, {
					Attacker = {},
					Victim = {
						Bind = {
							Part0 = RootPart,
							Part1 = self.Target.RootPart,
							Offset = self.GrabData.Offset,
						}						
					},
				} :: Types.GrabData))
				
				VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, {
					Animation = Anims[self.GrabData.Prefix.."Throw"],
					Speed = seq.Speed, 
				})
				
				VFXService:StartEffect(Players:GetPlayers(), "Animation", self.Target.instance, {
					Animation = Anims[self.GrabData.Prefix.."ThrowVictim"],
					Speed = seq.Speed, 
				})

				VFXService:StartEffect(Players:GetPlayers(), "Sound", RootPart, Sounds[self.GrabData.Prefix.."Grabbed"])
				
				if self.OnGrab then
					self.OnGrab(self.Data, self.Target)
				end
			end,},
			
			{self.GrabData.FinalFrame - 5, function(seq)
				seq.Cleaner:Remove("GrabObject")
			end,},
			
			{self.GrabData.FinalFrame, function(seq: Sequencer.Sequencer)
				CombatService:Attack{
					Attacker = character,
					Victim = self.Target,
					Info = self.Data.Throw,
				}
				
				if self.OnThrow then
					self.OnThrow(self.Data, self.Target)
				end
			end,}
		}
	}))

	self.Sequence = self.Janitor:Add(CombatService.CreateSequence(character, {
		Frames = {
			{0, function(seq)
				seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 12))
				seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

				table.clear(self.AlreadyHit)

				VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, {
					Animation = Anims[self.GrabData.Prefix.."Grab"],
					Speed = seq.Speed, 
				})

				VFXService:StartEffect(Players:GetPlayers(), "Sound", RootPart, Sounds[self.GrabData.Prefix.."Grab"])
				VFXService:StartEffect(Players:GetPlayers(), "Sound", RootPart, Sounds[self.GrabData.Prefix.."GrabVL"])
				
				self.Target = nil
			end,},
			
			{30, function(seq)
				local Targets = CombatService:Hitbox({
					Skill = self,
					Caster = character,
					Info = AttackInfo.Hitbox
				})	
				
				for _, Target in Targets do
					if self.Target then break end
					if table.find(self.AlreadyHit, Target) then
						continue
					end
					
					table.insert(self.AlreadyHit, Target)

					CombatService:Attack{
						Attacker = character,
						Victim = Target,
						Info = AttackInfo,
					}:andThen(function(Data: Types.AttackData)
						if Data.State.Success and Data.State.Continue and not self.GrabSequence:IsPlaying() then
							self.Target = Target

							self.GrabSequence:Play()
							seq:Stop()
						end
					end)
				end
			end,
			self.GrabData.EndHitFrame},
			
			{45},
		},
	}))
end

function Skill.Activate(self)	
	-- self.GrabData["Prefix"] =
	
	if self.Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end
	
	if self.GrabSequence and self.GrabSequence:IsPlaying() then
		self.GrabSequence:Await()
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
	
	if self.GrabSequence then
		self.GrabSequence:Stop()
	end

	VFXService:StopEffect(Players:GetPlayers(), "Animation", character.instance, {
		Animation = Anims[self.GrabData.Prefix.."Grab"],
	})
	--VFXService:StopEffect(Players:GetPlayers(), "Sound", RootPart, Sounds[self.GrabData.Prefix.."Grab"])
	--VFXService:StopEffect(Players:GetPlayers(), "Sound", RootPart, Sounds[self.GrabData.Prefix.."GrabVL"])
end

return Skill