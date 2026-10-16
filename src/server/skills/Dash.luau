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
		Speed = 50,
		Time = 0.25,
	},
}

const Dash_Style = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

const GetDashDirection = function(Normal)
	const angle = math.ceil(math.deg(math.atan2(Normal.X, -Normal.Z)) - 0.5)

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
	const character = self.Character
	const DashProperties = self.Data.DashProperties
	const RootPart = character.RootPart
	const Humanoid = character.Humanoid :: Humanoid
	const VFXService = Crane:GetService("VFXService")

	const CombatService = Crane:GetService("CombatService")

	const Anims = self.Spec.Data.Assets.Animations

	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
		Frames = {
			{
				1,
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

					const velocity = Instance.new("BodyVelocity") :: BodyVelocity
					velocity.MaxForce = Vector3.new(18_000, 0, 18_000)
					velocity.Velocity = RootPart.CFrame:VectorToWorldSpace(Normal) * 80
					velocity.Parent = RootPart

					TweenService:Create(velocity, Dash_Style, { Velocity = Vector3.zero }):Play()

					seq.Velocity = velocity

					seq.Cleaner:Set("Velocity", velocity)
				end,
			},

			--{10, function(seq)
			--	seq.Velocity.MaxForce = Vector3.new(9_000,0,9_000)
			--end,},

			{
				15,
				function(seq)
					seq.Cleaner:Remove("Velocity")
				end,
			},

			{ 20 },
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
