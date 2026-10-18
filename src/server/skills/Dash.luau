const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const TweenService = game:GetService("TweenService")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
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
	const character = self.Character
	const DashProperties = self.Data.DashProperties
	const RootPart = character.RootPart
	const Humanoid = character.Humanoid :: Humanoid
	const VFXService = Crane:GetService("VFXService")

	const CombatService = Crane:GetService("CombatService")

	const Anims = self.Spec.Data.Assets.Animations

	const DashTime = DashProperties.Time or 0.25
	const DashDecay = math.min(DashProperties.Decay or 0.1, DashTime)

	const HoldFrame = math.max(1, math.floor(DashTime * 60) - math.floor(DashDecay * 60))

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

					const direction = GetDashDirection(Normal)

					VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, {
						Animation = Anims["Dash" .. direction],
						SpecId = self.Spec.Data.Id,
					})

					ClearBodyMovers(RootPart)

					const velocity = Instance.new("BodyVelocity") :: BodyVelocity
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
					const velocity = seq.Velocity
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
	const Sequence = self.Sequence
	if Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end
end

function Skill:Interrupt()
	self.Sequence:Stop()
end

return Skill
