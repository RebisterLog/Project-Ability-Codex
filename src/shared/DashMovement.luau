--!native
--!optimize 2

--[=[ DashMovement

   Shared physics used by both layers of the Dash skill:

     * the client skill predicts the dash for the local player (the client owns
       its own character physics, so the local mover replicates);
     * the server skill drives the very same mover on Heartbeat for NPCs, which
       have no client to predict for them. Both paths call Apply() + Update()
       with the same Config, so their trajectories are identical.

   Physics notes:
     * LinearVelocity is a constraint: it enforces the requested velocity
       directly instead of pulling it in with a spring (the old BodyVelocity
       P coefficient made the character vibrate against ground friction);
     * there is deliberately NO AlignOrientation. The dash remembers its
       direction in the character's local space and follows RootPart rotation
       (shift-lock camera), so an orientation mover would feed back into that
       reference and make the character spiral. Camera/Humanoid owns rotation;
     * a ground dash keeps MaxAxesForce.Y at zero, so gravity is never fought;
     * an air dash (started while FloorMaterial is Air) gives Y the full force
       budget and targets zero vertical speed. The constraint then cancels
       gravity for the whole dash: the character moves strictly horizontally
       (the flat "hover" segment). At the end of the dash the Y budget is
       released again, so gravity immediately produces the falling arc.
       The mode is picked once at cast time so players and NPCs follow exactly
       the same path, even if the character lands mid-dash;
     * Update() steers with a capped turn rate and controls the tail of the
       dash: a short decaying slide on the ground and a soft distance cap in
       the air, with separate tunings for the two modes.
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
	ExitSpeed: number,
	TailFrames: number,
	AirHover: boolean,
	AirVerticalSpeed: number,
	AirMoveFrames: number,
	AirCapDistance: number,
	AirBrakeDistance: number,
	AirExitSpeed: number,
	AirTailFrames: number,
}

--- Plain-number description of what the constraint should request. No Roblox
--- globals here so the ground/air/end decisions can be unit-tested directly.
export type Motion = {
	Velocity: { x: number, y: number, z: number },
	Force: { x: number, y: number, z: number },
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
	Force: number,
	Hovering: boolean,
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

	ExitSpeed = 40,
	TailFrames = 20,

	-- Air dash: a flat, gravity-free hover for the powered part of the dash,
	-- followed by the normal falling arc once the mover releases Y.
	AirHover = true,
	AirVerticalSpeed = 0,
	AirMoveFrames = 18,
	AirCapDistance = 34,
	AirBrakeDistance = 8,
	AirExitSpeed = 45,
	AirTailFrames = 8,
} :: Config

function DashMovement.FramesToSeconds(frames: number): number
	return frames / 60
end

--- Pure resolver for the constraint request. `hovering` decides whether the
--- Y axis gets a force budget (air dash) or is left to gravity (ground dash /
--- released tail). Speeds and forces are plain scalars for testability.
function DashMovement.ResolveMotion(
	directionX: number,
	directionZ: number,
	speed: number,
	force: number,
	hovering: boolean,
	verticalSpeed: number
): Motion
	return {
		Velocity = {
			x = directionX * speed,
			y = if hovering then verticalSpeed else 0,
			z = directionZ * speed,
		},
		Force = {
			x = force,
			y = if hovering then force else 0,
			z = force,
		},
	}
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
	const hovering: boolean = Config.AirHover
		and humanoid ~= nil
		and humanoid.FloorMaterial == Enum.Material.Air

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
	const motion = DashMovement.ResolveMotion(
		direction.X,
		direction.Z,
		Config.Speed,
		force,
		hovering,
		Config.AirVerticalSpeed
	)

	const velocity = Instance.new("LinearVelocity")
	velocity.Name = "DashLinearVelocity"
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.Attachment0 = attachment
	velocity.VectorVelocity = Vector3.new(motion.Velocity.x, motion.Velocity.y, motion.Velocity.z)

	-- X/Z get the full budget. Y gets it too only for an air dash, where the
	-- constraint has to cancel gravity to hold the flat hover segment.
	velocity.ForceLimitsEnabled = true
	velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	velocity.MaxAxesForce = Vector3.new(motion.Force.x, motion.Force.y, motion.Force.z)
	velocity.Parent = rootPart

	-- Instant horizontal speed on the same frame instead of waiting for the
	-- mover to ramp up. An air dash also zeroes vertical speed so the flat
	-- segment starts immediately (a dash started in a fall is caught at its
	-- current height); a ground dash preserves Y so jumping/falling stays put.
	const current = rootPart.AssemblyLinearVelocity
	rootPart.AssemblyLinearVelocity = Vector3.new(
		motion.Velocity.x,
		if hovering then motion.Velocity.y else current.Y,
		motion.Velocity.z
	)

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
		Force = force,
		Hovering = hovering,
		Destroyed = false,
		Destroy = DestroyMover,
	}
end

--- Advances the dash by one frame: steering, mode-specific distance control
--- and the tail. Returns false when the dash has finished and the mover can be
--- destroyed. Both the client and the NPC server loop call this same function.
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

	-- The mode is fixed at cast time (see Apply), so a ground dash never
	-- suddenly starts hovering over a ledge and an air dash keeps its flat
	-- trajectory if it happens to land early.
	const hovering = handle.Hovering
	const moveSeconds =
		DashMovement.FramesToSeconds(if hovering then Config.AirMoveFrames else Config.MoveFrames)

	-- Safety net: a character stuck against geometry may never reach the cap,
	-- so the dash cannot stay alive forever.
	const maxFrames = if hovering
		then Config.AirMoveFrames + Config.AirTailFrames + 36
		else Config.MoveFrames + Config.SlideFrames + 36
	local speedFactor = 1
	local alive = handle.Elapsed < DashMovement.FramesToSeconds(maxFrames)

	if handle.Elapsed > moveSeconds then
		if hovering then
			-- In the air there is no friction; brake smoothly before the cap so
			-- the dash stays longer than on ground without flying away.
			if handle.Distance >= Config.AirCapDistance then
				alive = false
			else
				-- Never brake all the way to zero: reaching the cap with ~0
				-- speed reads as a dead stop followed by a vertical drop.
				const minFactor = Config.AirExitSpeed / Config.Speed
				speedFactor = math.clamp(
					(Config.AirCapDistance - handle.Distance) / Config.AirBrakeDistance,
					minFactor,
					1
				)
			end
		else
			-- Humanoid friction stops the character dead the moment the dash
			-- ends, so keep a short decaying slide to reach a usable distance.
			const slideSeconds = DashMovement.FramesToSeconds(Config.SlideFrames)
			const slideTime = handle.Elapsed - moveSeconds
			if slideTime >= slideSeconds then
				alive = false
			else
				speedFactor = 1 - slideTime / slideSeconds
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
		const exitSpeed = if hovering then Config.AirExitSpeed else Config.ExitSpeed
		const tail = tailDirection * exitSpeed

		-- Releasing the Y force budget is what starts the falling arc. It
		-- happens here, at the end of the flat segment, not later when the
		-- mover is finally destroyed after the tail.
		const motion = DashMovement.ResolveMotion(
			tailDirection.X,
			tailDirection.Z,
			exitSpeed,
			handle.Force,
			false,
			0
		)
		handle.Velocity.MaxAxesForce = Vector3.new(motion.Force.x, motion.Force.y, motion.Force.z)
		handle.Velocity.VectorVelocity = Vector3.new(motion.Velocity.x, 0, motion.Velocity.z)

		handle.TailElapsed += deltaTime
		handle.RootPart.AssemblyLinearVelocity = Vector3.new(tail.X, currentVelocity.Y, tail.Z)
		const tailSeconds = DashMovement.FramesToSeconds(
			if hovering then Config.AirTailFrames else Config.TailFrames
		)
		return handle.TailElapsed >= tailSeconds
	end

	-- Keep writing the Y target every frame so steering and braking never
	-- drop the hover; ground dashes keep the constraint's Y at zero.
	const motion = DashMovement.ResolveMotion(
		handle.CurrentDirection.X,
		handle.CurrentDirection.Z,
		Config.Speed * speedFactor,
		handle.Force,
		hovering,
		Config.AirVerticalSpeed
	)
	handle.Velocity.VectorVelocity =
		Vector3.new(motion.Velocity.x, motion.Velocity.y, motion.Velocity.z)
	return true
end

return DashMovement
