local RunService = game:GetService("RunService")

local function QuadBezier(p0, p1, p2, t)
	local x = (1 - t) * (1 - t) * p0.X + 2 * (1 - t) * t * p1.X + t * t * p2.X
	local y = (1 - t) * (1 - t) * p0.Y + 2 * (1 - t) * t * p1.Y + t * t * p2.Y
	local z = (1 - t) * (1 - t) * p0.Z + 2 * (1 - t) * t * p1.Z + t * t * p2.Z
	return Vector3.new(x, y, z)
end

local Bodypart = {}
Bodypart.__index = Bodypart

function Bodypart.new(instance: BasePart)
	for i, v in instance:QueryDescendants("BasePart") :: { BasePart } do
		v.CanCollide = false
		v.CastShadow = false
		v.Massless = true
		v.Anchored = false
	end

	instance.Anchored = true
	instance.CanCollide = false
	instance.CastShadow = false
	instance.Parent = workspace.Effects

	local trails = instance:QueryDescendants("#BarrageTrail")
	for i, trail in trails do
		trail.Enabled = true
	end

	return setmetatable({
		instance = instance,
		createTime = os.clock(),
	}, Bodypart)
end

function Bodypart:GetNextPos(
	originPart: BasePart,
	offsets: { A: CFrame, B: CFrame, C: CFrame },
	alpha: number,
	delta: number
)
	local pointA = originPart.CFrame:ToWorldSpace(offsets.A or CFrame.identity).Position
	local pointB = originPart.CFrame:ToWorldSpace(offsets.B or CFrame.identity).Position
	local pointC = originPart.CFrame:ToWorldSpace(offsets.C or CFrame.identity).Position

	local point = QuadBezier(pointA, pointB, pointC, alpha)
	local nextPoint = QuadBezier(pointA, pointB, pointC, alpha + delta)

	local current = self.instance.CFrame
	local look = CFrame.new(point, nextPoint)
	local rotate = CFrame.Angles(math.pi / 2, 0, 0)

	return current:Lerp(look * rotate, 0.5)
end

-- Don't use it
function Bodypart:Fly(
	originPart: BasePart,
	lifetime: number,
	offsets: { A: CFrame, B: CFrame, C: CFrame }
)
	local startTime = os.clock()

	self.runConnection = RunService.RenderStepped:Connect(function(delta)
		if os.clock() - startTime >= lifetime then
			self:Stop()
			return
		end

		local alpha = (os.clock() - startTime) / lifetime
		if alpha > 0.95 then
			self:Stop()
			return
		end

		--local pointA = originPart.CFrame:ToWorldSpace(offsets.A or CFrame.identity).Position
		--local pointB = originPart.CFrame:ToWorldSpace(offsets.B or CFrame.identity).Position
		--local pointC = originPart.CFrame:ToWorldSpace(offsets.C or CFrame.identity).Position

		--local point = QuadBezier(pointA, pointB, pointC, alpha)
		--local nextPoint = QuadBezier(pointA, pointB, pointC, alpha + delta)

		--local current = self.instance.CFrame
		--local look = CFrame.new(point, nextPoint)
		--local rotate = CFrame.Angles(math.pi / 2, 0, 0)

		self.instance.CFrame = self:GetNextPos(originPart, offsets, alpha)
	end)
end

function Bodypart:Stop()
	if self.runConnection then
		self.runConnection:Disconnect()
		self.runConnection = nil
	end

	if self.onReach then self:onReach() end

	self = nil
end

function Bodypart:Destroy()
	self:Stop()
end

return Bodypart
