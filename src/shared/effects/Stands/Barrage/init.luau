const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)

const Bodypart = require(script.Bodypart)

type BarrageStopData = {
	UUID: string | number?,
}

type BarrageData = {
	Type: "Arm" | "Leg"?,
	Character: Model?,
	UUID: string | number?,
	Rate: number?,
	Lifetime: number?,
}

return {
	Barrages = {},

	Validate = function(self, data: BarrageData)
		return true
	end,

	storeBodyPart = function(part: BasePart)
		part.Parent = nil
	end,

	unstoreBodyPart = function(part: BasePart)
		-- restored by Bodypart.new when re-used
	end,

	onStart = function(self, data: BarrageData)
		const character = data.Character
		const uuid = data.UUID
		const bodyType = data.Type or "Arm"
		const rate = data.Rate or 30
		const lifetime = data.Lifetime or 0.3

		if self.Barrages[uuid] then self:onStop({ UUID = uuid }) end

		const leftName = if bodyType == "Arm" then "Left Arm" else "Left Leg"
		const rightName = if bodyType == "Arm" then "Right Arm" else "Right Leg"

		const originLeft = character:FindFirstChild(leftName) :: BasePart
		const originRight = character:FindFirstChild(rightName) :: BasePart
		const torso = character:FindFirstChild("HumanoidRootPart") :: BasePart

		if not originLeft or not originRight or not torso then return end

		const cleaner = Crane.Buttler.new()

		const cacheL = cleaner:Construct(Crane.CacheTab, originLeft, 5, function(part)
			self.storeBodyPart(part)
		end, function(part)
			self.unstoreBodyPart(part)
		end)

		const cacheR = cleaner:Construct(Crane.CacheTab, originRight, 5, function(part)
			self.storeBodyPart(part)
		end, function(part)
			self.unstoreBodyPart(part)
		end)

		const interval = 1 / rate
		local lastSpawn = os.clock()
		local isLeft = true
		const components = {}

		cleaner:Set(
			"Spawn",
			RunService.PreRender:Connect(function()
				if os.clock() - lastSpawn <= interval then return end

				lastSpawn = os.clock()

				const side = if isLeft then -1 else 1
				const part = if isLeft then cacheL:Get() else cacheR:Get()

				const randomSide = if math.random() > 0.5 then 1 else -1
				const offsetA = CFrame.new(
					side * math.random(50, 100) / 100,
					math.random(-100, 100) / 100,
					1
				) + Vector3.zAxis * -3
				const offsetB = CFrame.new(
					side * math.random(0, 400) / 100,
					math.random(-550, 550) / 100,
					-2
				) + Vector3.zAxis * -3
				const offsetC = CFrame.new(
					math.random(0, 50) / 100 * side,
					math.random(0, 100) / 100 * randomSide,
					-9 + (randomSide * math.random(0, 50) / 100)
				)

				const component = Bodypart.new(part, {
					A = offsetA,
					B = offsetB,
					C = offsetC,
				}, torso)

				component.isLeft = isLeft
				table.insert(components, component)
				isLeft = not isLeft
			end)
		)

		const parts = {}
		const cframes = {}
		cleaner:Connect(RunService.RenderStepped, function()
			table.clear(parts)
			table.clear(cframes)

			for i = #components, 1, -1 do
				const component = components[i]
				const alpha = (os.clock() - component.createTime) / lifetime

				if alpha >= 1 then
					(if component.isLeft then cacheL else cacheR):Add(component.instance)
					component:Destroy()
					table.remove(components, i)
				else
					table.insert(parts, component.instance)
					table.insert(cframes, component:GetNextPos(torso, component.points, alpha))
				end
			end

			if #parts > 0 then
				workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
			end
		end)

		self.Barrages[uuid] = cleaner
	end,

	onStop = function(self, data: BarrageStopData)
		const uuid = if data ~= nil then data.UUID else nil
		if uuid == nil then return end

		const cleaner = self.Barrages[uuid]
		if not cleaner then return end

		cleaner:Remove("Spawn")

		task.delay(1, function()
			-- allow in-flight fists to finish, then clean up
			if self.Barrages[uuid] == cleaner then
				self.Barrages[uuid] = nil
				cleaner:Destroy()
			end
		end)
	end,
}
