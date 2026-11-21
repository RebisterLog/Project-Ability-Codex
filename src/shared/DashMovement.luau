--!native
--!optimize 2

--[=[ DashMovement

   Shared physics used by both layers of the Dash skill:

     * the client skill predicts the dash for the local player (the client owns
       its own character physics, so the local mover replicates);
     * the server skill drives the very same mover on Heartbeat for NPCs, which
       have no client to predict for them. Both paths call Apply() + Update()
       with the same Config, so their trajectories are identical.

   The whole dash is one LinearVelocity constraint. Its VectorVelocity is
   sampled once at cast time from the world-space movement direction, flattened
   to the horizontal plane, and never steered afterwards:

     * RelativeTo.World keeps that vector independent of RootPart rotation, so
       shift-lock can turn the character without bending the trajectory;
     * the Y target is zero and the Y force budget stays enabled for the whole
       dash, so gravity cannot tilt the path on ground or in the air;
     * the dash holds one constant speed for most of its life, then eases the
       constraint's target down to a fixed, lower exit speed along the same
       world direction. The direction is never steered; only the magnitude
       tapers, and the character leaves with that exact speed on ground and in
        the air. No ramp-up and no mode switch.

   Nothing writes AssemblyLinearVelocity by hand. Both phases only change
   LinearVelocity properties; callers just create it, tick a timer and destroy
   it when the exit phase ends.

   The force budget is intentionally moderate. A huge LinearVelocity budget
   keeps ramming the rig into a wall after contact, which can tip the Humanoid
   into Ragdoll; the smaller budget still holds the requested speed on flat
   ground and in the air but gives way on impact.
]=]

const DashMovement = {}

export type Config = {
	Speed: number,
	MoveFrames: number,
	BrakeFrames: number,
	ExitFrames: number,
	ExitSpeed: number,
	IFrameFrames: number,
	Cooldown: number,
	Force: number,
}

--- Plain-number description of what the constraint should request. No Roblox
--- globals here so the resolver can be unit-tested directly.
export type Motion = {
	Velocity: { x: number, y: number, z: number },
	Force: { x: number, y: number, z: number },
}

export type DashMover = {
	WorldDirection: Vector3,
	--- Object-space snapshot used only to pick the dash animation. It is never
	--- fed back into movement.
	Normal: Vector3,
	Velocity: LinearVelocity?,
	Attachment: Attachment?,
	Elapsed: number,
	ExitElapsed: number,
	Destroyed: boolean,
	Destroy: (self: DashMover) -> (),
}

DashMovement.Config = {
	-- One constant speed for the whole powered part of the dash.
	Speed = 100,
	MoveFrames = 12,

	-- Last part of the dash eases the target from Speed down to ExitSpeed.
	-- Ease-out spends the drop early and settles softly onto the exit speed.
	BrakeFrames = 6,

	-- Then the same constraint holds this fixed residual speed for a few frames.
	-- It is a fraction of the dash speed: enough to feel like momentum rather
	-- than a dead stop, small enough not to stretch the falling arc too much.
	ExitFrames = 2,
	ExitSpeed = 32,
	IFrameFrames = 8,
	Cooldown = 1.5,

	-- Authority of the constraint per axis, not an acceleration: the requested
	-- velocity is constant, so the budget only decides how firmly the solver
	-- holds it. Kept moderate so a wall hit does not keep ramming the rig into
	-- the surface and tip the Humanoid into Ragdoll. Y stays enabled to cancel
	-- gravity and keep the path flat in the air as well as on the ground.
	Force = 45_000,
} :: Config

function DashMovement.FramesToSeconds(frames: number): number
	return frames / 60
end

--- Speed target for the current frame. Flat until the brake window, then an
--- ease-out drop (fast at first, soft landing) to the fixed exit speed. Pure
--- numbers only so the whole curve can be unit-tested without Roblox globals.
function DashMovement.ResolveSpeed(
	elapsed: number,
	moveSeconds: number,
	brakeSeconds: number,
	speed: number,
	exitSpeed: number
): number
	const brakeStart = moveSeconds - brakeSeconds
	if elapsed <= brakeStart then return speed end
	if elapsed >= moveSeconds then return exitSpeed end

	const t = (elapsed - brakeStart) / brakeSeconds
	const progress = 1 - (1 - t) * (1 - t)
	return speed + (exitSpeed - speed) * progress
end

--- Resolves the constraint request for one frame. The Y velocity is always zero
--- and the Y force budget is always on: no mode switch between ground and air.
--- The speed argument comes from ResolveSpeed, including the brake tail.
function DashMovement.ResolveMotion(
	directionX: number,
	directionZ: number,
	speed: number,
	force: number
): Motion
	return {
		Velocity = {
			x = directionX * speed,
			y = 0,
			z = directionZ * speed,
		},
		Force = {
			x = force,
			y = force,
			z = force,
		},
	}
end

--- World-space horizontal unit vector, sampled once. Falls back to the
--- CFrame's LookVector (also flattened) when there is no movement input.
function DashMovement.GetDirection(moveDirection: Vector3, fallback: CFrame): Vector3
	local direction = Vector3.new(moveDirection.X, 0, moveDirection.Z)
	if direction.Magnitude < 0.001 then
		const look = fallback.LookVector
		direction = Vector3.new(look.X, 0, look.Z)
	end
	if direction.Magnitude < 0.001 then direction = Vector3.new(0, 0, -1) end

	return direction.Unit
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

--- Creates the mover on `rootPart` and returns an idempotent handle. Register
--- it in a Janitor/Buttler with the "Destroy" method so any interrupt, respawn
--- or sequence stop tears the constraint down.
function DashMovement.Apply(rootPart: BasePart, moveDirection: Vector3): DashMover
	const Config = DashMovement.Config

	-- Sampled once, in world space. Nothing in Update() reads the character
	-- rotation again, so turning the camera/body cannot steer the dash.
	const direction = DashMovement.GetDirection(moveDirection, rootPart.CFrame)
	const motion = DashMovement.ResolveMotion(direction.X, direction.Z, Config.Speed, Config.Force)

	-- A stale dash (previous activation / interrupted cast) must never leave a
	-- second mover fighting the new one. The old names are cleaned up too.
	for _, name in
		{
			"DashLinearVelocity",
			"DashVelocity",
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

	const velocity = Instance.new("LinearVelocity")
	velocity.Name = "DashLinearVelocity"
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.Attachment0 = attachment
	velocity.VectorVelocity = Vector3.new(motion.Velocity.x, motion.Velocity.y, motion.Velocity.z)

	-- Per-axis budget with Y enabled: the constraint cancels gravity for the
	-- whole dash, so the path is horizontal whatever the surface underneath.
	velocity.ForceLimitsEnabled = true
	velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	velocity.MaxAxesForce = Vector3.new(motion.Force.x, motion.Force.y, motion.Force.z)
	velocity.Parent = rootPart

	-- Animation only. Snapshot at cast time; it is not used for steering.
	const localDir = rootPart.CFrame:VectorToObjectSpace(direction)
	const flat = Vector3.new(localDir.X, 0, localDir.Z)
	const normal = if flat.Magnitude > 0.001 then flat.Unit else Vector3.new(0, 0, -1)

	return {
		WorldDirection = direction,
		Normal = normal,
		Velocity = velocity,
		Attachment = if createdAttachment then attachment else nil,
		Elapsed = 0,
		ExitElapsed = 0,
		Destroyed = false,
		Destroy = DestroyMover,
	}
end

--- Advances the dash timer. The target stays flat, then eases down to the exit
--- speed over the last BrakeFrames; the short hold after MoveFrames lets the
--- constraint settle there before the caller removes it. Only VectorVelocity
--- is written — never AssemblyLinearVelocity.
function DashMovement.Update(handle: DashMover, deltaTime: number): boolean
	if handle.Destroyed or not handle.Velocity then return false end

	const Config = DashMovement.Config
	handle.Elapsed += deltaTime

	const moveSeconds = DashMovement.FramesToSeconds(Config.MoveFrames)
	const currentSpeed = DashMovement.ResolveSpeed(
		handle.Elapsed,
		moveSeconds,
		DashMovement.FramesToSeconds(Config.BrakeFrames),
		Config.Speed,
		Config.ExitSpeed
	)
	const motion = DashMovement.ResolveMotion(
		handle.WorldDirection.X,
		handle.WorldDirection.Z,
		currentSpeed,
		Config.Force
	)
	handle.Velocity.VectorVelocity =
		Vector3.new(motion.Velocity.x, motion.Velocity.y, motion.Velocity.z)

	if handle.Elapsed < moveSeconds then return true end

	-- Y force stays enabled through the hold, so the character does not start
	-- falling until the mover is actually destroyed.
	handle.ExitElapsed += deltaTime
	return handle.ExitElapsed < DashMovement.FramesToSeconds(Config.ExitFrames)
end

return DashMovement
