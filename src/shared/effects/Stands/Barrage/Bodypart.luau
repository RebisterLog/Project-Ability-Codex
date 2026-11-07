const RunService = game:GetService("RunService")

const QuadBezier = function(p0, p1, p2, t)
	const x = (1 - t) * (1 - t) * p0.X + 2 * (1 - t) * t * p1.X + t * t * p2.X
	const y = (1 - t) * (1 - t) * p0.Y + 2 * (1 - t) * t * p1.Y + t * t * p2.Y
	const z = (1 - t) * (1 - t) * p0.Z + 2 * (1 - t) * t * p1.Z + t * t * p2.Z
	return Vector3.new(x, y, z)
end

const Bodypart = {}
Bodypart.__index = Bodypart

function Bodypart.new(instance: BasePart, points: { A: Vector3, B: Vector3, C: Vector3 })
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

	const trails = instance:QueryDescendants("#BarrageTrail")
	for i, trail in trails do
		trail.Enabled = true
	end

	-- Cache world-space control points at spawn so owner movement cannot reshape
	-- the fist's path.
	return setmetatable({
		instance = instance,
		createTime = os.clock(),
		pointA = points.A,
		pointB = points.B,
		pointC = points.C,
	}, Bodypart)
end

function Bodypart:GetNextPos(alpha: number)
	const point = QuadBezier(self.pointA, self.pointB, self.pointC, alpha)
	const nextPoint = QuadBezier(self.pointA, self.pointB, self.pointC, alpha + 0.001)

	const current = self.instance.CFrame
	const look = CFrame.new(point, nextPoint)
	const rotate = CFrame.Angles(1.5, 0, 0)

	return current:Lerp(look * rotate, 0.5)
end

-- Don't use it
function Bodypart:Fly(lifetime: number)
	const startTime = os.clock()

	self.runConnection = RunService.RenderStepped:Connect(function()
		if os.clock() - startTime >= lifetime then
			self:Stop()
			return
		end

		const alpha = (os.clock() - startTime) / lifetime
		if alpha > 0.95 then
			self:Stop()
			return
		end

		self.instance.CFrame = self:GetNextPos(alpha)
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
