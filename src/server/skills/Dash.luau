local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)
local Enums = require(ServerScriptService.server.Enums)
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local types = require(ServerScriptService.server.types)

local Skill: types.SkillData = {
	DisplayName = "Dash",
	Cooldown = 1.5,
	SkillCharacters = {
		"Escape",
		"Defense",
		"ComboStarter"
	},
	
	DashProperties = {
		Speed = 50,
		Time = 0.25
	}
}

local function GetDashDirection(Normal)
	local angle = math.ceil(math.deg(math.atan2(Normal.X, -Normal.Z)) - 0.5)

	if angle > 55 and angle < 125 then
		return "Right"
	elseif angle < -55 and angle > -125 then
		return "Left"
	elseif angle <= -125 or angle >= 125 then
		return "Back"
	end

	return "Forward"
end

function Skill:onInit()
	local character = self.Character
	local DashProperties = self.Data.DashProperties
	local RootPart = character.RootPart
	local Humanoid = character.Humanoid :: Humanoid
	local VFXService = Crane:GetService("VFXService")
	
	local CombatService = Crane:GetService("CombatService")
	
	local Anims = self.Spec.Data.Assets.Animations

	self.Sequence = self.Janitor:Add(CombatService.CreateSequence(character, {
		Frames = {
			{1, function(seq)
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 0))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))
					seq.Cleaner:Add(character:AddParameter("IFrames", Enums.IFrames.True))
					
					local Normal = RootPart.CFrame:VectorToObjectSpace(Humanoid.MoveDirection)
					if Normal == Vector3.zero then
						Normal = Vector3.new(0,0,-1)
					end
					
					local direction = GetDashDirection(Normal)
					
					VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, {
						Animation = Anims["Dash"..direction],
						SpecId = self.Spec.Data.Id
					})

					local velocity = Instance.new("BodyVelocity") :: BodyVelocity
					velocity.MaxForce = Vector3.new(18_000, 0, 18_000)
					velocity.Velocity = RootPart.CFrame:VectorToWorldSpace(Normal) * 80
					velocity.Parent = RootPart
					
					seq.Cleaner:Set("Velocity", velocity)
				end,
			}, 

			{15, function(seq)
				seq.Cleaner:Remove("Velocity")
			end},
			
			{20}
		}
	}))
end

function Skill:Activate()
	local Sequence = self.Sequence
	if Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end
end

function Skill:Interrupt()
	self.Sequence:Stop()
end

return Skill