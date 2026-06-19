local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local types = require(ServerScriptService.server.types)
local Enums = require(ServerScriptService.server.Enums)
local Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)

local Skill: types.SkillData = {
	DisplayName = "Shell Launch",
	Cooldown = 2.5,
	
	SkillCharacters = {
		"ComboExtender",
		"Hit",
		"Ragdoll",
		"Projectile",
		"IgnoreBlock",
	},

	AttackInfo = {
		--Priority = Enums.IFrames.Ragdoll,
		Damage = 10,

		Block = {
			Blockable = false,
			PerfectBlockable = false,
			BlockBreak = false,
			BlockCancel = true,
			BlockIgnore = true,
		},

		Stun = {
			Priority = Enums.Stun.Medium,
			Duration = 0.7
		},

		Ragdoll = {
			Duration = 0.75,
		},

		Knockback = {
			Duration = 0.1,
			Velocity = Vector3.new(0, 30, 0),
			Speed = 40,
		},
		
		Angular = {
			Velocity = Vector3.new(-25,0,0),
			Duration = 0.2,
		},
	},
}

local function FindNearestCharacter(point: Vector3, exclude: {types.Character}): (types.Character?, number?)
	local characters = Crane:GetAllComponents("Character")
	
	local nearestCharacter, nearestDistance = nil, math.huge
	
	for i, character in characters do
		if table.find(exclude, character) then continue end
		
		local distance = (character.RootPart.Position - point).Magnitude
		if distance < nearestDistance then
			nearestCharacter = character
			nearestDistance = distance
		end
	end
	
	return nearestCharacter, nearestDistance
end

function Skill.onInit(self)
	local character = self.Character :: types.Character
	local RootPart = character.RootPart
	local Humanoid = character.Humanoid
	local VFXService = Crane:GetService("VFXService")
	local CombatService = Crane:GetService("CombatService")

	local Anims = self.Spec.Data.Assets.Animations
	local Sounds = self.Spec.Data.Assets.Sounds
	local Models = self.Spec.Data.Assets.Models
	local AttackInfo = self.Data.AttackInfo

	self.AlreadyHit = {}
	self.Shell = nil
	
	self.ShellSequence = Sequencer.new({
		Frames = {
			{0, function(seq)
				local shell = seq.Cleaner:Clone(Models.Shell) :: Model
				self.Shell = shell

				local velocity = seq.Cleaner:Construct(Instance, "BodyVelocity") :: BodyVelocity
				velocity.MaxForce = Vector3.new(10_000, 0, 10_000)
				velocity.Velocity = RootPart.CFrame.LookVector * 100
				velocity.P = math.huge
				velocity.Parent = shell.PrimaryPart

				local attachment =  seq.Cleaner:Construct(Instance, "Attachment") :: Attachment
				attachment.Parent = shell.PrimaryPart

				local gyro =  seq.Cleaner:Construct(Instance, "BodyGyro")
				gyro.Parent = shell.PrimaryPart

				local params = RaycastParams.new()
				params.RespectCanCollide = true
				params.FilterType = Enum.RaycastFilterType.Exclude
				params:AddToFilter(shell)

				seq.Cleaner:Add(RunService.Heartbeat:Connect(function(touch)
					local result = workspace:Raycast(shell.PrimaryPart.Position, velocity.Velocity.Unit * 5, params)
					if result and result.Instance and result.Instance.CollisionGroup ~= "Default" then return end

					if result and result.Normal then
						local norm = result.Normal
						local reflect = (velocity.Velocity - (2 * velocity.Velocity:Dot(norm) * norm))
						
						local nearest, dist = FindNearestCharacter(attachment.WorldPosition, {character})
						
						
						VFXService:StartEffect(Players:GetPlayers(), "Sound", shell.PrimaryPart, Sounds["ShellBounce"])


						if nearest and dist < 100 then
							local aimVector = (nearest.RootPart.Position - attachment.WorldPosition).Unit
							
							-- If Target is in 60 angles from reflect angle
							if reflect.Unit:Angle(aimVector) < math.rad(60) then
								velocity.Velocity = aimVector * reflect.Magnitude * Vector3.new(1, 0, 1)
							else
								velocity.Velocity = reflect * Vector3.new(1, 0, 1)
							end
						else
							velocity.Velocity = reflect * Vector3.new(1, 0, 1)
						end
						
						table.clear(self.AlreadyHit)
					end
				end))
				
				local slideSound = Sounds["ShellSlide"].Sound:Clone() :: Sound
				slideSound.Parent = shell.PrimaryPart
				slideSound.Looped = true
				slideSound:Play()

				shell:PivotTo(RootPart.CFrame * CFrame.new(0,0,-3))
				shell.Parent = workspace
				
				Crane.Utils.ChangeNetworkOwner(shell, nil)
			end,},

			{5, function(seq)
				local targets = CombatService:Hitbox({
					Skill = self,
					Caster = character,
					Info = {
						Size = 3,
						Origin = self.Shell.PrimaryPart.CFrame,
						--Debug = true,
					},
				})

				for _, target in targets do
					if table.find(self.AlreadyHit, target) then
						return
					end
					
					table.insert(self.AlreadyHit, target)
					
					CombatService:Attack{
						Attacker = character,
						Victim = target,
						Info = AttackInfo,
					}
				end
			end,
			120},
			
			{121},
		}
	})

	self.Sequence = self.Janitor:Add(CombatService.CreateSequence(character, {
		Frames = {
			{0, function(seq)
				seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 12))
				
				table.clear(self.AlreadyHit)
				
				VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, {
					Animation = Anims["ShellLaunch"],
					Speed = seq.Speed, 
				})
				
				VFXService:StartEffect(Players:GetPlayers(), "EquipShell", character.instance, Models.Shell)
			end,},
			
			{30, function()
				self.ShellSequence:Play()
			end,}
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

	local Anims = self.Spec.Data.Assets.Animations

	if self.Sequence then
		self.Sequence:Stop()
	end
	
	--VFXService:StopEffect(Players:GetPlayers(), "Animation", character.instance, {
	--	Animation = Anims["ShellLaunch"].Animation,
	--})
end

return Skill