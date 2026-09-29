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

	Tag = "OnlyForStand",

	SkillCharacters = {
		"Hit",
		"ComboExtender",
		"Blockable"
	},

	BarrageInfo = {
		Hitbox = {
			Size = Vector3.new(6,6,8),
			Offset = CFrame.new(0,0,-4),
			MovementCorrection = true,
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
			ToFront = 5,
			Speed = 6,
			Duration = 0.05,
			Velocity = Vector3.new(0, 0.75, 0)
		},
	} :: types.AttackInfo,

	PostBarrageInfo = {
		Hitbox = {
			Size = Vector3.new(6,6,10),
			Offset = CFrame.new(0,0,-6),
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
			MaxForce = Vector3.new(100_000, 0, 100_000)
		},
	}
}

function Skill.onInit(self)
	local character = self.Character
	local RootPart = character.RootPart
	local VFXService = Crane:GetService("VFXService")
	local CombatService = Crane:GetService("CombatService")

	local Anims = self.Spec.Data.Assets.Stand.Animations
	local Sounds = self.Spec.Data.Assets.Stand.Sounds
	local Models = self.Spec.Data.Assets.Stand.Models

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{0, function(seq)
				seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 12))
				seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

				VFXService:StartEffect(Players:GetPlayers(), "Animation", self.Caster.instance, {
					Animation = Anims["Barrage"],
					Speed = seq.Speed, 
				})
				VFXService:StartEffect(Players:GetPlayers(), "Sound", RootPart, Sounds["BarrageVL"])
				VFXService:StartEffect(Players:GetPlayers(), "Sound", RootPart, Sounds["Barrage"])

				self.BarrageUUID = os.clock()

				--VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", {
				--	UUID = self.BarrageUUID,
				--	Particle = Models["Barrage"],
				--	Origin = character.RootPart,
				--})
				
				seq.Cleaner:Add(function()
					VFXService:StopEffect(Players:GetPlayers(), "Animation", self.Caster.instance, {
						Animation = Anims["Barrage"].Animation,
					})

					VFXService:StopEffect(Players:GetPlayers(), "Barrage", self.BarrageUUID)
					VFXService:StopEffect(Players:GetPlayers(), "Sound", RootPart, Sounds["BarrageVL"].Sound)
					VFXService:StopEffect(Players:GetPlayers(), "Sound", RootPart, Sounds["Barrage"].Sound)
				end)
			end,},

			{4, function()
				
				VFXService:StartEffect(Players:GetPlayers(), "Barrage",
					self.Caster.instance,
					"Arm",
					{
						Offsets = {
							A = CFrame.new(1 * math.random(0, 2), math.random(-1, 1), 1),
							B = CFrame.new(1 * math.random(-6, 6), math.random(-5.5, 5.5), -2),
							C = CFrame.new(0, 0, -7)
						},
						Rate = 120,
						Lifetime = 0.3,
					},
					self.BarrageUUID
				)
			end,},

			{5, function(seq, frame)
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
			170},
			
			{171, function()
				VFXService:StopEffect(Players:GetPlayers(), "Barrage", self.BarrageUUID)
				VFXService:StopEffect(Players:GetPlayers(), "Sound", RootPart, Sounds["BarrageVL"].Sound)
				VFXService:StopEffect(Players:GetPlayers(), "Sound", RootPart, Sounds["Barrage"].Sound)
			end,},

			{173, function()
				VFXService:StartEffect(Players:GetPlayers(), "Sound", RootPart, Sounds["BarrageHit"])
			end,},
			
			{180, function()
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
			
			
			
			{190},
		}
	}) :: Sequencer.Sequencer)
end

function Skill.Activate(self: types.Skill)
	if self.Sequence then
		local StandService = Crane:GetService("StandService")

		local stand = StandService:GetStand(self.Character) :: types.Stand
		local isStandActive = if stand then stand:IsActive() else false
		
		self.Caster = stand
		
		self.Sequence.Cleaner:Add(self.Deactivated:Once(function()
			if self.Sequence.CurrentFrame <= 160 then
				self.Sequence:Stop()
			end
		end))

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
	--VFXService:StopEffect(Players:GetPlayers(), "Sound", RootPart, Sounds[self.GrabData.Prefix.."Grab"])
	--VFXService:StopEffect(Players:GetPlayers(), "Sound", RootPart, Sounds[self.GrabData.Prefix.."GrabVL"])
end

return Skill