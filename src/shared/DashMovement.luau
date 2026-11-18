--!native
--!optimize 2

--[=[ DashMovement

   Shared physics used by both layers of the Dash skill:

     * the client skill predicts the dash for the local player (the client owns
       its own character physics, so the local mover replicates);
     * the server skill applies the very same mover to NPCs, which have no
       client to predict for them.

   Physics notes:
     * VectorVelocity.Y and MaxAxesForce.Y are always zero, so gravity is never
       fought and the character cannot be launched into the air;
     * LinearVelocity is a constraint: it enforces the requested velocity
       directly instead of pulling it in with a spring (the old BodyVelocity
       P coefficient made the character vibrate against ground friction);
     * there is deliberately NO AlignOrientation. The dash remembers its
       direction in the character's local space and follows RootPart rotation
       (shift-lock camera), so an orientation mover would feed back into that
       reference and make the character spiral. Camera/Humanoid owns rotation;
     * Update() steers with a capped turn rate and controls the tail of the
       dash: a short decaying slide on the ground (where the Humanoid would
       otherwise stop the character almost instantly) and a soft distance cap
       in the air (where inertia alone would carry the character 2-3x farther).
]=]

const DashMovement = {}

export type Config = {
	Speed: number,
	MoveFrames: number,
	SlideFrames: number,
	IFrameFrames: number,
	Cooldown: number,
	Acceleration: number,
	MinForce: number,
	MaxForce: number,
	TurnRate: number,
	AirCapDistance: number,
	AirBrakeDistance: number,
	ExitSpeed: number,
	TailFrames: number,
}

export type DashMover = {
	RootPart: BasePart,
	Humanoid: Humanoid?,
	StartPosition: Vector3,
	LocalDirection: Vector3,
	Velocity: LinearVelocity?,
	Attachment: Attachment?,
	CurrentDirection: Vector3,
	Elapsed: number,
	Distance: number,
	TailElapsed: number,
	Destroyed: boolean,
	Destroy: (self: DashMover) -> (),
}

DashMovement.Config = {
	Speed = 100,
	MoveFrames = 8,
	SlideFrames = 5,
	IFrameFrames = 8,
	Cooldown = 1.5,
	Acceleration = 20_000,
	MinForce = 60_000,
	MaxForce = 120_000,
	TurnRate = 720,
	AirCapDistance = 22,
	AirBrakeDistance = 6,
	ExitSpeed = 40,
	TailFrames = 20,
} :: Config

function DashMovement.FramesToSeconds(frames: number): number
	return frames / 60
end

--- World-space horizontal unit vector. Falls back to the CFrame's LookVector
--- (also flattened) when the humanoid reports no movement input.
function DashMovement.GetDirection(moveDirection: Vector3, fallback: CFrame): Vector3
	local direction = Vector3.new(moveDirection.X, 0, moveDirection.Z)
	if direction.Magnitude < 0.001 then
		const look = fallback.LookVector
		direction = Vector3.new(look.X, 0, look.Z)
	end
	if direction.Magnitude < 0.001 then direction = Vector3.new(0, 0, -1) end

	return direction.Unit
end

--- Remembers a world-space direction in the character's local space. Used at
--- dash start so the dash keeps its heading relative to the player while the
--- RootPart turns (shift-lock camera), instead of staying fixed in world space.
function DashMovement.GetLocalDirection(rootPart: BasePart, worldDirection: Vector3): Vector3
	const localDir = rootPart.CFrame:VectorToObjectSpace(worldDirection)
	const flat = Vector3.new(localDir.X, 0, localDir.Z)
	if flat.Magnitude < 0.001 then return Vector3.new(0, 0, -1) end
	return flat.Unit
end

--- Rebuilds that heading in world space from the current character rotation.
function DashMovement.GetWorldDirection(rootPart: BasePart, localDirection: Vector3): Vector3
	const world = rootPart.CFrame:VectorToWorldSpace(localDirection)
	const flat = Vector3.new(world.X, 0, world.Z)
	if flat.Magnitude < 0.001 then return Vector3.new(0, 0, -1) end
	return flat.Unit
end

--- Object-space direction, used only to pick DashForward/Back/Left/Right.
function DashMovement.GetDashDirection(Normal: Vector3): string
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

local function DestroyMover(self: DashMover)
	if self.Destroyed then return end
	self.Destroyed = true

	if self.Velocity then
		self.Velocity:Destroy()
		self.Velocity = nil
	end
	if self.Attachment then
		self.Attachment:Destroy()
		self.Attachment = nil
	end
end

--- Creates the mover on `rootPart` and returns an idempotent handle.
--- Register the handle in a Janitor/Buttler with the "Destroy" method so any
--- interrupt, respawn or sequence stop tears it down.
function DashMovement.Apply(
	rootPart: BasePart,
	moveDirection: Vector3,
	humanoid: Humanoid?
): DashMover
	const Config = DashMovement.Config

	const direction = DashMovement.GetDirection(moveDirection, rootPart.CFrame)

	-- A stale dash (previous activation / interrupted cast) must never leave a
	-- second mover fighting the new one. The old names are cleaned up too.
	for _, name in
		{
			"DashLinearVelocity",
			"DashVelocity",
			"DashAlignOrientation",
			"DashAttachment",
		}
	do
		const stale = rootPart:FindFirstChild(name)
		if stale then stale:Destroy() end
	end

	local attachment = (rootPart:FindFirstChild("RootAttachment") :: Attachment?)
		or rootPart:FindFirstChildOfClass("Attachment")
	local createdAttachment = false
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "DashAttachment"
		attachment.Parent = rootPart
		createdAttachment = true
	end

	const force =
		math.clamp(rootPart.AssemblyMass * Config.Acceleration, Config.MinForce, Config.MaxForce)

	const velocity = Instance.new("LinearVelocity")
	velocity.Name = "DashLinearVelocity"
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.Attachment0 = attachment
	velocity.VectorVelocity = direction * Config.Speed

	-- Per-axis limits: X/Z get the full budget, Y gets zero so the constraint
	-- never counteracts gravity (a scalar MaxForce could not express this).
	velocity.ForceLimitsEnabled = true
	velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	velocity.MaxAxesForce = Vector3.new(force, 0, force)
	velocity.Parent = rootPart

	-- Instant horizontal speed on top of the constraint: the dash reacts on the
	-- same frame instead of waiting for the mover to ramp up. Y is preserved so
	-- jumping/falling stays untouched.
	const current = rootPart.AssemblyLinearVelocity
	rootPart.AssemblyLinearVelocity =
		Vector3.new(direction.X * Config.Speed, current.Y, direction.Z * Config.Speed)

	return {
		RootPart = rootPart,
		Humanoid = humanoid,
		StartPosition = rootPart.Position,
		LocalDirection = DashMovement.GetLocalDirection(rootPart, moveDirection),
		Velocity = velocity,
		Attachment = if createdAttachment then attachment else nil,
		CurrentDirection = direction,
		Elapsed = 0,
		Distance = 0,
		TailElapsed = 0,
		Destroyed = false,
		Destroy = DestroyMover,
	}
end

--- Advances the dash by one client frame: steering, ground slide and air cap.
--- Returns false when the dash has finished and the mover can be destroyed.
function DashMovement.Update(handle: DashMover, deltaTime: number): boolean
	if handle.Destroyed or not handle.Velocity then return false end

	const Config = DashMovement.Config
	handle.Elapsed += deltaTime

	-- Steering: the stored direction is relative to RootPart, so turning the
	-- shift-lock camera turns the dash with the character.
	const desired = DashMovement.GetWorldDirection(handle.RootPart, handle.LocalDirection)
	const current = handle.CurrentDirection
	const angle = math.acos(math.clamp(current:Dot(desired), -1, 1))
	if angle > 0.0001 then
		const maxStep = math.rad(Config.TurnRate) * deltaTime
		const alpha = math.clamp(maxStep / angle, 0, 1)
		handle.CurrentDirection = (current + (desired - current) * alpha).Unit
	end

	const offset = handle.RootPart.Position - handle.StartPosition
	handle.Distance = Vector3.new(offset.X, 0, offset.Z).Magnitude

	const moveSeconds = DashMovement.FramesToSeconds(Config.MoveFrames)
	const onGround = handle.Humanoid ~= nil and handle.Humanoid.FloorMaterial ~= Enum.Material.Air

	-- Safety net: a character stuck against geometry may never reach the air
	-- cap, so the dash cannot stay alive forever.
	const maxSeconds = DashMovement.FramesToSeconds(Config.MoveFrames + Config.SlideFrames + 36)
	local speedFactor = 1
	local alive = handle.Elapsed < maxSeconds

	if handle.Elapsed > moveSeconds then
		if onGround then
			-- Humanoid friction stops the character dead the moment the dash
			-- ends, so keep a short decaying slide to reach a usable distance.
			const slideSeconds = DashMovement.FramesToSeconds(Config.SlideFrames)
			const slideTime = handle.Elapsed - moveSeconds
			if slideTime >= slideSeconds then
				alive = false
			else
				speedFactor = 1 - slideTime / slideSeconds
			end
		else
			-- In the air there is no friction; brake smoothly before the cap so
			-- the dash stays longer than on ground without flying away.
			if handle.Distance >= Config.AirCapDistance then
				alive = false
			else
				-- Never brake all the way to zero: reaching the cap with ~0
				-- speed reads as a dead stop followed by a vertical drop.
				const minFactor = Config.ExitSpeed / Config.Speed
				speedFactor = math.clamp(
					(Config.AirCapDistance - handle.Distance) / Config.AirBrakeDistance,
					minFactor,
					1
				)
			end
		end
	end

	if not alive then
		-- Hold the residual tail with the still-living constraint for a few
		-- frames. Writing it once and destroying the mover on the same frame
		-- lets the Humanoid/solver eat it, which reads as a full stop.
		const currentVelocity = handle.RootPart.AssemblyLinearVelocity
		const horizontal = Vector3.new(currentVelocity.X, 0, currentVelocity.Z)
		const tailDirection = if horizontal.Magnitude > 0.001
			then horizontal.Unit
			else handle.CurrentDirection
		const tail = tailDirection * Config.ExitSpeed

		handle.TailElapsed += deltaTime
		handle.Velocity.VectorVelocity = tail
		handle.RootPart.AssemblyLinearVelocity = Vector3.new(tail.X, currentVelocity.Y, tail.Z)
		return handle.TailElapsed >= DashMovement.FramesToSeconds(Config.TailFrames)
	end

	handle.Velocity.VectorVelocity = handle.CurrentDirection * Config.Speed * speedFactor
	return true
end

return DashMovement
