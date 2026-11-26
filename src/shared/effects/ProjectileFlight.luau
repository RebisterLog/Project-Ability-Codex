const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Ballistics = require(ReplicatedStorage.shared.flight.Ballistics)

--[=[ ProjectileFlight

   Purely client-side visual for a server projectile. The server sends the
   flight numbers ONCE (StartEffect) and keeps only the hitbox trajectory;
   every viewer clones the model locally and predicts the same path with the
   shared Ballistics integrator. No replicated body, no Roblox physics.

   A single StopEffect with the UUID tears the visual down early (hit, wall,
   lifetime, interrupt).
]=]

type ReflectionConfig = {
	Enabled: boolean?,
	Restitution: number?,
	MaxBounces: number?,
	IgnoreCharacters: boolean?,
	SurfaceOffset: number?,
}

type FlightData = {
	UUID: string?,
	Model: Model | BasePart?,
	Position: Vector3?,
	Direction: Vector3?,
	Speed: number?,
	Gravity: Vector3?,
	Orientation: CFrame?,
	OrientToVelocity: boolean?,
	Lifetime: number?,
	MaxDistance: number?,
	Reflection: ReflectionConfig?,
	-- Server clock at the moment the projectile was created.
	StartAt: number?,
}

type FlightState = {
	Cleaner: typeof(Crane.Buttler.new()),
	Connection: RBXScriptConnection?,
	Position: Vector3,
	Velocity: Vector3,
	Gravity: Vector3,
	Orientation: CFrame?,
	OrientationFollowsVelocity: boolean,
	Lifetime: number,
	MaxDistance: number?,
	Traveled: number,
	Elapsed: number,
	Reflection: any?,
	StartAt: number,
	StartPosition: Vector3,
	StartVelocity: Vector3,
	-- Straight flight: position is derived from absolute server time, never
	-- accumulated from client frame deltas.
	Analytic: boolean,
	Stopped: boolean,
}

const Running: { [string]: FlightState } = {}

const function noop() end

const function stopFlight(uuid: string, state: FlightState)
	if state.Stopped then return end
	state.Stopped = true
	if Running[uuid] == state then Running[uuid] = nil end
	state.Cleaner:Destroy()
end

-- An authored pivot often sits in the grip while the blade sticks out along
-- its LookVector. PivotTo() would then put the grip on the projectile point and
-- leave the visible knife hanging off one end of the hitbox. Move the clone's
-- pivot to the centre of its visible bounds so PivotTo() centres the model on
-- the server's hitbox, not on an invisible handle.
const SIGNS = { -1, 1 } :: { number }

const function centrePivotOnVisibleModel(model: Model | BasePart)
	if not model:IsA("Model") or not model.PrimaryPart then return end

	const pivot = model:GetPivot()
	const inverse = pivot:Inverse()
	local min, max = math.huge, -math.huge

	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") or part.Transparency >= 0.999 then continue end

		const relative = inverse * part.CFrame
		const half = part.Size * 0.5
		for _, sx in SIGNS do
			for _, sy in SIGNS do
				for _, sz in SIGNS do
					-- Forward is -Z in pivot-local space.
					const distance = -(
						relative * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)
					).Z
					if distance < min then min = distance end
					if distance > max then max = distance end
				end
			end
		end
	end

	if min == math.huge then return end
	const centre = (min + max) * 0.5
	if math.abs(centre) < 0.01 then return end

	-- PivotTo() sets `CFrame * PivotOffset`, so a negative local Z offsets the
	-- pivot forward along LookVector and pulls the model back by `centre`.
	model.PrimaryPart.PivotOffset = CFrame.new(0, 0, -centre)
end

-- The authored Trail attachments sit ~1 stud off the knife's centreline.
-- After the model is turned onto the flight axis that becomes a visible streak
-- running parallel to the hitbox but beside it. Snap every trail attachment
-- onto the pivot's look axis on the local clone only.
const function alignTrailAttachments(model: Model | BasePart)
	if not model:IsA("Model") then return end

	const pivot = model:GetPivot()
	const look = pivot.LookVector
	if look.Magnitude < 0.001 then return end

	for _, trail in model:GetDescendants() do
		if not trail:IsA("Trail") then continue end
		for _, attachment in { trail.Attachment0, trail.Attachment1 } do
			if not attachment then continue end
			const parent = attachment.Parent
			if not parent or not parent:IsA("PVInstance") then continue end

			const world = attachment.WorldCFrame.Position
			const relative = world - pivot.Position
			const target = pivot.Position + look * relative:Dot(look)
			const parentCFrame = if parent:IsA("BasePart")
				then parent.CFrame
				else (parent :: Attachment).CFrame
			attachment.Position = parentCFrame:Inverse() * target
		end
	end
end

return {
	onStart = function(_, data: FlightData)
		const uuid = data.UUID
		if not uuid or Running[uuid] then return end

		const template = data.Model
		const position = data.Position
		const direction = data.Direction
		if not template or not position or not direction then return end

		const cleaner = Crane.Buttler.new()

		const visual = template:Clone()
		cleaner:Add(visual)
		const parts = if visual:IsA("BasePart")
			then { visual }
			else visual:QueryDescendants("BasePart") :: { BasePart }
		for _, part in parts do
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
		centrePivotOnVisibleModel(visual)
		alignTrailAttachments(visual)
		visual.Parent = workspace:FindFirstChild("Effects") or workspace

		const config = data.Reflection
		local reflection: any = nil
		if config then
			const params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.RespectCanCollide = true
			params:AddToFilter(workspace:FindFirstChild("Live") or workspace)
			reflection = {
				Params = params,
				Enabled = config.Enabled == true,
				Restitution = config.Restitution or 1,
				MaxBounces = config.MaxBounces or -1,
				IgnoreCharacters = config.IgnoreCharacters ~= false,
				SurfaceOffset = config.SurfaceOffset or 0.05,
			}
		end

		const startAt = data.StartAt or workspace:GetServerTimeNow()
		const now = workspace:GetServerTimeNow()
		const startVelocity = direction.Unit * (data.Speed or 100)
		const gravity = data.Gravity or Vector3.zero
		const analytic = gravity.Magnitude < 0.001 and (not config or config.Enabled ~= true)
		const elapsed0 = math.max(0, now - startAt)
		const startPosition = if analytic then position + startVelocity * elapsed0 else position

		const state: FlightState = {
			Cleaner = cleaner,
			Connection = nil,
			Position = startPosition,
			Velocity = startVelocity,
			Gravity = gravity,
			Orientation = data.Orientation,
			OrientationFollowsVelocity = data.OrientToVelocity == true,
			Lifetime = data.Lifetime or 5,
			MaxDistance = data.MaxDistance,
			Traveled = if analytic then startVelocity.Magnitude * elapsed0 else 0,
			Elapsed = elapsed0,
			Reflection = reflection,
			StartAt = startAt,
			StartPosition = position,
			StartVelocity = startVelocity,
			Analytic = analytic,
			Stopped = false,
		}
		Running[uuid] = state

		const function pivot(nextPosition: Vector3, velocity: Vector3)
			const cframe = if state.OrientationFollowsVelocity
				then CFrame.lookAt(nextPosition, nextPosition + velocity)
				else CFrame.new(nextPosition) * (state.Orientation or CFrame.identity.Rotation)
			if visual:IsA("Model") then
				visual:PivotTo(cframe)
			else
				visual.CFrame = cframe
			end
		end
		pivot(state.Position, state.Velocity)

		state.Connection = cleaner:Add(RunService.RenderStepped:Connect(function(deltaTime: number)
			if state.Stopped then return end

			-- Absolute server time, not accumulated client frame deltas: a late
			-- packet or a different frame rate cannot shift the visual forward.
			state.Elapsed = math.max(0, workspace:GetServerTimeNow() - state.StartAt)
			if state.Elapsed > state.Lifetime then
				stopFlight(uuid, state)
				return
			end

			local grounded = false
			if state.Analytic then
				state.Position = state.StartPosition + state.StartVelocity * state.Elapsed
				state.Velocity = state.StartVelocity
				state.Traveled = state.StartVelocity.Magnitude * state.Elapsed
			else
				const nextPosition, nextVelocity, hitGround = Ballistics.step(
					state.Position,
					state.Velocity,
					state.Gravity,
					deltaTime,
					state.Reflection
				)
				state.Traveled += (nextPosition - state.Position).Magnitude
				state.Position = nextPosition
				state.Velocity = nextVelocity
				grounded = hitGround
			end
			pivot(state.Position, state.Velocity)

			if grounded or (state.MaxDistance and state.Traveled >= state.MaxDistance) then
				stopFlight(uuid, state)
			end
		end))

		cleaner:Add(function()
			state.Stopped = true
			if Running[uuid] == state then Running[uuid] = nil end
		end)
	end,

	onStop = function(_, data: { UUID: string? })
		const uuid = data.UUID
		const state = uuid and Running[uuid]
		if state then stopFlight(uuid, state) end
	end,
}
