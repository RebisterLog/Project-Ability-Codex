--!native
--!optimize 2

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const StarterPlayer = game:GetService("StarterPlayer")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const MovementRules = require(ReplicatedStorage.shared.MovementRules)

const LocalPlayer = Players.LocalPlayer

--[=[ MovementService

   Applies the authoritative movement parameters replicated into the player
   proxy (`CharacterState.Parameters`) to the local Humanoid, layered with any
   number of client-side minimum WalkSpeed sources (Run prediction, cutscenes,
   etc.). The highest minimum wins, clamped by the server's maximum, so a local
   prediction can never override a server restraint.
]=]

const MovementService = Crane:CreateService({
	Name = "MovementService",
	LoadOrder = -5,
})

function MovementService.Apply(self: typeof(MovementService))
	const humanoid = self.Humanoid
	if not humanoid or humanoid.Health <= 0 then return end

	-- The proxy is rebuilt on respawn and its CharacterState is briefly empty;
	-- applying defaults then would snap the humanoid.
	const source = self.PlayerService.Proxy()
	const characterState = source and source.CharacterState
	if not characterState or not characterState.Parameters then return end

	const parameters = characterState.Parameters
	local minWalkSpeed = parameters.MinWalkSpeed
	for _, speed in self.LocalMinWalkSpeeds do
		minWalkSpeed = math.max(minWalkSpeed, speed)
	end

	humanoid.WalkSpeed = MovementRules.GetWalkSpeed(minWalkSpeed, parameters.MaxWalkSpeed)

	const jumpPower = MovementRules.GetJumpPower(parameters.MaxJumpPower)
	humanoid.JumpPower = jumpPower
	humanoid.JumpHeight = (jumpPower / MovementRules.BaseJumpPower)
		* StarterPlayer.CharacterJumpHeight
end

function MovementService.SetLocalMinWalkSpeed(
	self: typeof(MovementService),
	source: string,
	speed: number?
)
	if speed then
		self.LocalMinWalkSpeeds[source] = speed
	else
		self.LocalMinWalkSpeeds[source] = nil
	end

	self:Apply()
end

function MovementService.Attach(self: typeof(MovementService), character: Model)
	self.CharacterVersion += 1
	const version = self.CharacterVersion
	table.clear(self.LocalMinWalkSpeeds)

	self.Humanoid = nil
	const humanoid = character:WaitForChild("Humanoid") :: Humanoid
	if version ~= self.CharacterVersion then return end

	self.Humanoid = humanoid
	self:Apply()
end

function MovementService.onStart(self: typeof(MovementService))
	self.PlayerService = Crane:GetService("PlayerService")
	self.LocalMinWalkSpeeds = {}
	self.CharacterVersion = 0
	self.Cleaner = Crane.Buttler.new()

	self.Cleaner:Add(
		self.PlayerService.Proxy:Subscribe(
			"AnyChange",
			{ "CharacterState", "Parameters" },
			function()
				self:Apply()
			end
		)
	)

	self.Cleaner:Add(LocalPlayer.CharacterAdded:Connect(function(character)
		self:Attach(character)
	end))

	if LocalPlayer.Character then self:Attach(LocalPlayer.Character) end
end

function MovementService.Destroy(self: typeof(MovementService))
	self.CharacterVersion += 1
	self.Cleaner:Destroy()
end

return MovementService
