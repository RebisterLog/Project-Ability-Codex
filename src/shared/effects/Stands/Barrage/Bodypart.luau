const RunService = game:GetService("RunService")

const QuadBezier = function(p0, p1, p2, t)
	const x = (1 - t) * (1 - t) * p0.X + 2 * (1 - t) * t * p1.X + t * t * p2.X
	const y = (1 - t) * (1 - t) * p0.Y + 2 * (1 - t) * t * p1.Y + t * t * p2.Y
	const z = (1 - t) * (1 - t) * p0.Z + 2 * (1 - t) * t * p1.Z + t * t * p2.Z
	return Vector3.new(x, y, z)
end

const Bodypart = {}
Bodypart.__index = Bodypart

function Bodypart.new(instance: BasePart, points: { A: any, B: any, C: any }, torso: BasePart?)
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

	return setmetatable({
		instance = instance,
		createTime = os.clock(),
		points = points,
		torso = torso,
	}, Bodypart)
end

function Bodypart:_resolvePoints(torso: BasePart?)
	local t = torso or self.torso
	local p = self.points

	if t and typeof(p.A) == "CFrame" then
		local cf = t.CFrame
		return cf:ToWorldSpace(p.A).Position, cf:ToWorldSpace(p.B).Position, cf:ToWorldSpace(p.C).Position
	end

	return p.A, p.B, p.C
end

function Bodypart:GetNextPos(torsoOrAlpha: any, offsets: any?, alpha: number?)
	local a, t
	if typeof(torsoOrAlpha) == "number" then
		a = torsoOrAlpha
		t = nil
	else
		t = torsoOrAlpha
		a = alpha or 0
		if offsets then
			self.points = offsets
		end
	end

	const pA, pB, pC = self:_resolvePoints(t)
	const point = QuadBezier(pA, pB, pC, a)
	const nextPoint = QuadBezier(pA, pB, pC, math.min(a + 0.001, 1))

	if point == nextPoint then
		return self.instance.CFrame
	end

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
