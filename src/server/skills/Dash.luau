local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Enums = require(ServerScriptService.server.Enums)
local Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)
local types = require(ServerScriptService.server.types)

local Skill: types.SkillData = {
	DisplayName = "Dash",
	Cooldown = 1.5,
	SkillCharacters = {
		"Escape",
		"Defense",
		"ComboStarter",
	},

	DashProperties = {
		Speed = 80,
		Time = 0.25,
		Decay = 0.1,
		MaxForce = Vector3.new(60_000, 0, 60_000),
	},
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

local function ClearBodyMovers(RootPart: BasePart)
	for _, Mover in RootPart:GetChildren() do
		if Mover:IsA("BodyMover") then Mover:Destroy() end
	end
end

function Skill:onInit()
	local character = self.Character
	local DashProperties = self.Data.DashProperties
	local RootPart = character.RootPart
	local Humanoid = character.Humanoid :: Humanoid
	local VFXService = Crane:GetService("VFXService")

	local CombatService = Crane:GetService("CombatService")

	local Anims = self.Spec.Data.Assets.Animations

	local DashTime = DashProperties.Time or 0.25
	local DashDecay = math.min(DashProperties.Decay or 0.1, DashTime)

	local HoldFrame = math.max(1, math.floor(DashTime * 60) - math.floor(DashDecay * 60))
	local RemoveFrame = math.max(HoldFrame + 1, math.floor(DashTime * 60))
	local EndFrame = RemoveFrame + 5

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				0,
				function(seq)
					seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 0))
					seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))
					seq.Cleaner:Add(character:AddParameter("IFrames", Enums.IFrames.True))

					local Normal = RootPart.CFrame:VectorToObjectSpace(Humanoid.MoveDirection)
					if Normal == Vector3.zero then Normal = Vector3.new(0, 0, -1) end

					local direction = GetDashDirection(Normal)

					VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, {
						Animation = Anims["Dash" .. direction],
						SpecId = self.Spec.Data.Id,
					})

					ClearBodyMovers(RootPart)

					local velocity = Instance.new("BodyVelocity") :: BodyVelocity
					velocity.Name = "DashVelocity"
					velocity.MaxForce = DashProperties.MaxForce or Vector3.new(60_000, 0, 60_000)
					if DashProperties.P then velocity.P = DashProperties.P end
					velocity.Velocity = RootPart.CFrame:VectorToWorldSpace(Normal)
						* (DashProperties.Speed or 80)
					velocity.Parent = RootPart

					seq.Velocity = velocity

					seq.Cleaner:Set("Velocity", velocity)
				end,
			},

			{
				HoldFrame,
				function(seq)
					local velocity = seq.Velocity
					if not velocity then return end

					TweenService:Create(
						velocity,
						TweenInfo.new(DashDecay, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ Velocity = Vector3.zero }
					):Play()

					task.delay(0.25, function()
					    seq.Cleaner:Remove("Velocity")
					end)
				end,
			},
--
-- 			{
-- 				RemoveFrame,
-- 				function(seq)
--
-- 				end,
-- 			},
--
-- 			{ EndFrame },
		},
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
