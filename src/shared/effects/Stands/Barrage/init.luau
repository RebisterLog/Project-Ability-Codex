const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)

const Bodypart = require(script.Bodypart)

type BarrageData = {
	-- The limb pair the barrage flies from.
	Type: "Arm" | "Leg",
	Character: Model,
	UUID: string,
	Rate: number,
	Lifetime: number?,
	-- Part whose Attachment0 trails and Attachment1 are copied onto every thrown
	-- fist, so each punch drags the same ribbons as the kick barrage.
	Trail: BasePart?,
	-- One-shot swing cloned onto the stand root while the fists fly.
	Swing: Sound?,
	SwingVolume: number?,
}

type BarrageStopData = {
	UUID: string?,
}

-- The barrage faded its ribbons down once they were on screen.
const TRAIL_FADE_DELAY = 0.15
const TRAIL_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.7),
	NumberSequenceKeypoint.new(1, 0.7),
})

-- The swing loop played a sound every 0.09 seconds.
const SWING_INTERVAL = 0.09

const TRAIL_ATTACHMENT_NAMES = { "Attachment0", "Attachment1" }

local function lightEmissionOf(part: BasePart): number
	if part.Material == Enum.Material.Neon then return Random.new():NextInteger(100, 150) / 10 end

	return Random.new():NextInteger(0, 10) / 10
end

-- Cached fists are reused, so the ribbons of the previous punch go first.
local function clearTrail(part: BasePart)
	for _, name in TRAIL_ATTACHMENT_NAMES do
		const attachment = part:FindFirstChild(name)

		if attachment then attachment:Destroy() end
	end
end

local function addTrail(part: BasePart, trailSource: BasePart, color: Color3, emission: number)
	const trailSourceStart = trailSource:FindFirstChild("Attachment0")
	const trailSourceEnd = trailSource:FindFirstChild("Attachment1")

	if trailSourceStart == nil or trailSourceEnd == nil then return end

	const trailEnd = trailSourceEnd:Clone()
	trailEnd.Parent = part

	const trailStart = trailSourceStart:Clone()
	trailStart.Parent = part

	for _, trail in trailStart:GetChildren() do
		trail.Attachment0 = trailStart
		trail.Attachment1 = trailEnd

		if trail.Name == "Color" then
			trail.Color = ColorSequence.new(color)
			trail.LightEmission = emission
		elseif trail.Name == "Trail" then
			task.delay(TRAIL_FADE_DELAY, function()
				trail.Transparency = TRAIL_TRANSPARENCY
			end)
		end
	end
end

return {
	Barrages = {},

	Validate = function(self, data: BarrageData)
		return data.Character ~= nil and data.UUID ~= nil and data.Rate ~= nil
	end,

	storeBodyPart = function(part: BasePart, pos: Vector3)
		clearTrail(part)
		part.Parent = nil
		part.Position = pos
	end,

	unstoreBodyPart = function(part: BasePart, character: Model)
		--part.CFrame = character:GetPivot()
		--part.Parent = workspace.Effects
	end,

	onStart = function(self, data: BarrageData)
		local character, uuid = data.Character, data.UUID
		if not (character and uuid) then return end

		const originParts: { BasePart } = if data.Type == "Arm"
			then { character:FindFirstChild("Left Arm"), character:FindFirstChild("Right Arm") }
			else { character:FindFirstChild("Left Leg"), character:FindFirstChild("Right Leg") }

		if #originParts < 2 then return end

		const torso = character:FindFirstChild("HumanoidRootPart") :: BasePart
		if not torso then return end

		const cleaner = Crane.Buttler.new()

		const cacheL = cleaner:Construct(
			Crane.CacheTab,
			originParts[1],
			5,
			self.storeBodyPart,
			function(part)
				self.unstoreBodyPart(part, character)
			end
		)

		const cacheR = cleaner:Construct(
			Crane.CacheTab,
			originParts[2],
			5,
			self.storeBodyPart,
			function(part)
				self.unstoreBodyPart(part, character)
			end
		)

		const interval = 1 / data.Rate
		local lastSpawn = os.clock()

		local isLeft = true

		const components = {}

		-- Every punch cycles through both fist colours, left then right.
		const colors = { originParts[1].Color, originParts[2].Color }
		const emissions = { lightEmissionOf(originParts[1]), lightEmissionOf(originParts[2]) }
		const colorIndexes = { 1, 1 }

		local lastSwing = 0

		cleaner:Set(
			"Spawn",
			RunService.PreRender:Connect(function()
				if os.clock() - lastSpawn <= interval then return end

				lastSpawn = os.clock()

				const side = isLeft and -1 or 1
				const part = isLeft and cacheL:Get() or cacheR:Get()
				const originCFrame = torso.CFrame
				const targetPosition = (originCFrame * CFrame.new(
					math.random() / 2,
					math.random() / 2,
					-8.5
				)).Position
				const startPosition = (originCFrame * CFrame.new(
					math.random(100, 200) / 100 * side,
					math.random(-100, 200) / 100,
					math.random(0, 100) / 100
				)).Position
				const movementDirection = -(startPosition - targetPosition).Unit
				const points = {
					A = startPosition,
					B = startPosition
						+ movementDirection * ((startPosition - targetPosition).Magnitude / 2)
						+ originCFrame.RightVector * side * (math.random(0, 600) / 100)
						+ originCFrame.UpVector * (math.random(-600, 600) / 100),
					C = targetPosition,
				}
				const component = Bodypart.new(part, points)

				if data.Trail then
					const slot = if part.Name == "Right Arm" or part.Name == "Right Leg"
						then 2
						else 1
					const colorIndexesForSlot = colorIndexes[slot]
					local nextIndex = colorIndexesForSlot + 1

					if colorIndexesForSlot == #colors then nextIndex = 1 end

					addTrail(part, data.Trail, colors[colorIndexesForSlot], emissions[nextIndex])
					colorIndexes[slot] = nextIndex
				end

				if data.Swing and os.clock() - lastSwing >= SWING_INTERVAL then
					lastSwing = os.clock()

					const swing = data.Swing:Clone()
					swing.PlaybackSpeed *= Random.new():NextNumber(1, 1.25)
					swing.Volume = (data.SwingVolume or 0.5) * Random.new():NextNumber(0.75, 1.25)
					swing.Parent = torso
					swing.PlayOnRemove = true
					swing:Destroy()
				end

				component.isLeft = isLeft

				table.insert(components, component)
				isLeft = not isLeft

				part.CFrame = CFrame.new(startPosition, targetPosition) * CFrame.Angles(1.5, 0, 0)
				part.Parent = workspace.Effects
			end)
		)

		const parts = {}
		const cframes = {}
		cleaner:Connect(RunService.RenderStepped, function()
			table.clear(parts)
			table.clear(cframes)

			for i, component in components do
				const alpha = (os.clock() - component.createTime) / (data.Lifetime or 1)

				if alpha > 0.95 then
					(component.isLeft and cacheL or cacheR):Add(component.instance)

					component:Destroy()
					table.remove(components, i)
				else
					table.insert(parts, component.instance)
					table.insert(cframes, component:GetNextPos(alpha))
				end
			end

			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end)

		self.Barrages[uuid] = cleaner
	end,

	onStop = function(self, data: BarrageStopData)
		local barrage = self.Barrages[data.UUID]
		if barrage then
			barrage:Remove("Spawn")

			task.delay(1, function()
				barrage:Destroy()
			end)
		end
	end,
}
