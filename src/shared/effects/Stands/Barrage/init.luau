local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)

local Bodypart = require(script.Bodypart)

type BarrageProps = {
	Offsets: {
		A: CFrame,
		B: CFrame,
		C: CFrame
	},
	Rate: number,
	Lifetime: number,
}

return {
	Barrages = {},
	
	Validate = function(self, character: Model, bodyPart: "Arm" | "Leg", props: BarrageProps, uuid: string)
		return true
	end,
	

	storeBodyPart = function(part: BasePart, pos: Vector3)
		part.Parent = nil
		part.Position = pos
	end,

	unstoreBodyPart = function(part: BasePart, character: Model)
		--part.CFrame = character:GetPivot()
		--part.Parent = workspace.Effects
	end,
	
	onStart = function(self, character: Model, bodyPart: "Arm" | "Leg", props: BarrageProps, uuid: string)
		local originParts: {BasePart} = bodyPart == "Arm" 
			and {character:FindFirstChild("Left Arm"), character:FindFirstChild("Right Arm")}
			or {character:FindFirstChild("Left Leg"), character:FindFirstChild("Right Leg")}
		
		if #originParts < 2 then return end
		
		local torso = character:FindFirstChild("HumanoidRootPart") ::  BasePart
		if not torso then return end
		
		local cleaner = Crane.Buttler.new()

		local cacheL = cleaner:Construct(Crane.CacheTab,
			originParts[1],
			5,
			
			self.storeBodyPart,
			function(part)
				self.unstoreBodyPart(part, character)
			end
		)
		
		local cacheR = cleaner:Construct(Crane.CacheTab,
			originParts[2],
			5,

			self.storeBodyPart,
			function(part)
				self.unstoreBodyPart(part, character)
			end
		)
		
		local interval = 1 / props.Rate
		local lastSpawn = os.clock()
		
		local isLeft = true
		
		local components = {}
		
		cleaner:Set("Spawn", RunService.PreRender:Connect(function()
			if os.clock() - lastSpawn <= interval then return end
			
			lastSpawn = os.clock()
			
			local side = isLeft and -1 or 1
			local part = isLeft and cacheL:Get() or cacheR:Get()
			local component = Bodypart.new(part)
			
			local randomSide = math.random() > 0.5 and 1 or -1
			local randomOffsets = {
				A = CFrame.new(side * math.random(0.5, 1), math.random(-1, 1), 1) + Vector3.zAxis * -3,
				B = CFrame.new(side * math.random(0, 4), math.random(-5.5, 5.5), -2) + Vector3.zAxis * -3,
				C = CFrame.new(math.random(0, 0.5) * side, math.random(0, 1) * randomSide, -9 + (randomSide * math.random(0, 0.5))),
			}
			
			component.isLeft = isLeft
			component.offsets = randomOffsets
			
			table.insert(components, component)
			isLeft = not isLeft
			
			part.CFrame = torso.CFrame:ToWorldSpace(randomOffsets.A)
			part.Parent = workspace.Effects
		end))
		
		local parts = {}
		local cframes = {}
		cleaner:Connect(RunService.RenderStepped, function(delta)
			table.clear(parts); table.clear(cframes)
			
			for i, component in components do
				local alpha = (os.clock() - component.createTime) / (props.Lifetime or 1)
				
				if alpha > 0.95 then
					(component.isLeft and cacheL or cacheR):Add(component.instance)
					
					component:Destroy()
					table.remove(components, i)
				else
					table.insert(parts, component.instance)
					table.insert(cframes,
						component:GetNextPos(torso, component.offsets, alpha, delta)
					)
				end
			end
			
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end)
		
		
		self.Barrages[uuid] = cleaner
	end,
	
	onStop = function(self, uuid: string)
		if self.Barrages[uuid] then
			self.Barrages[uuid]:Remove("Spawn")
			
			task.delay(1, function()
				self.Barrages[uuid]:Destroy()
			end)
		end
	end,
}