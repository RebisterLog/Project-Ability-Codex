const function Wait(duration)
	duration = duration or 1 / 60

	local elapsedTime = 0

	repeat
		elapsedTime += game.RunService.Heartbeat:Wait()
	until elapsedTime >= duration

	return elapsedTime
end

type StepVelocityData = {
	Character: Model?,
	Velocity: Vector3?,
	EndVelocity: Vector3?,
	Speed: number?,
	EndSpeed: number?,
	Direction: Vector3?,
	Normal: Vector3?,
	MaxForce: Vector3?,
	Time: number?,
	TimeDelay: number?,
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
	Distance: number?,
	MaxDistance: number?,
	RaycastParameters: RaycastParams?,
	Filter: { Instance }?,
	Turn: boolean?,
	Override: boolean?,
}

type StepVelocityStopData = {
	Character: Model?,
}

return {
	Validate = function(self, data: StepVelocityData)
		return true
	end,

	onStart = function(self, data: StepVelocityData)
		local rootPart = data.Character and data.Character:FindFirstChild("HumanoidRootPart")
		if not rootPart or not rootPart:IsA("BasePart") then return end

		local character = data.Character

		local startVelocity = data.Velocity or Vector3.zero
		local endVelocity = data.EndVelocity or startVelocity

		local startSpeed = data.Speed or 1
		local endSpeed = data.EndSpeed or startSpeed

		local direction = data.Direction or Vector3.zero
		local normal = data.Normal or Vector3.zero

		local maxForce = data.MaxForce or Vector3.new(1e5, 0, 1e5)

		local duration = data.Time or 0.2
		local animationDuration = duration == math.huge and 0.2 or duration

		local easingStyle = data.EasingStyle or Enum.EasingStyle.Linear
		local easingDirection = data.EasingDirection or Enum.EasingDirection.Out

		local timeDelay = data.TimeDelay or 0

		local distance = data.Distance
		local maxDistance = data.MaxDistance

		local raycastParams = data.RaycastParameters

		if not raycastParams then
			raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Exclude

			local filterInstances = {
				rootPart,
				character,
			}

			if data.Filter then
				for _, instance in data.Filter do
					table.insert(filterInstances, instance)
				end
			end

			raycastParams.FilterDescendantsInstances = filterInstances
			raycastParams.CollisionGroup = "Default"
		end

		local worldNormal = rootPart.CFrame:VectorToWorldSpace(normal)

		local function getDirection()
			if data.Turn then return direction + rootPart.CFrame:VectorToWorldSpace(normal) end

			return direction + worldNormal
		end

		local existingVelocity = rootPart:FindFirstChild("StepVelocity")

		if existingVelocity then
			if data.Override == false then return end
			existingVelocity.Parent = nil
		end

		local elapsedTime = 0
		local currentSpeed = startSpeed

		local function calculateVelocity()
			local alpha = math.clamp(elapsedTime / animationDuration, 0, 1)

			local easingAlpha = game.TweenService:GetValue(alpha, easingStyle, easingDirection)

			local interpolatedVelocity = startVelocity ~= endVelocity
					and startVelocity:Lerp(endVelocity, easingAlpha)
				or startVelocity

			local velocity = getDirection() * math.lerp(currentSpeed, endSpeed, easingAlpha)

			local unitDirection = velocity.Unit
			currentSpeed = velocity.Magnitude

			if maxDistance then
				local raycastDistance = distance or maxDistance

				local raycastResult = workspace:Raycast(rootPart.Position, velocity, raycastParams)

				if raycastResult then
					raycastDistance = (rootPart.Position - raycastResult.Position).Magnitude
				end

				currentSpeed = math.lerp(
					0,
					currentSpeed,
					math.clamp(raycastDistance, 0, maxDistance) / maxDistance
				)

				velocity = unitDirection * currentSpeed
			end

			return interpolatedVelocity + velocity
		end

		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.Name = "StepVelocity"
		bodyVelocity.Velocity = calculateVelocity()
		bodyVelocity.MaxForce = maxForce

		if existingVelocity then
			task.defer(function()
				bodyVelocity.Parent = rootPart
			end)
		else
			bodyVelocity.Parent = rootPart
		end

		task.spawn(function()
			local previousTime = os.clock()

			while elapsedTime <= animationDuration + timeDelay do
				local currentTime = os.clock()
				local deltaTime = currentTime - previousTime

				previousTime = currentTime

				elapsedTime += deltaTime
				bodyVelocity.Velocity = calculateVelocity()

				Wait()
			end

			bodyVelocity:Destroy()
		end)

		return bodyVelocity
	end,

	onStop = function(self, data: StepVelocityStopData)
		local character = data.Character
		if not character then return end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then return end

		local bodyVelocity = rootPart:FindFirstChild("StepVelocity")
		if bodyVelocity then bodyVelocity:Destroy() end
	end,
}
