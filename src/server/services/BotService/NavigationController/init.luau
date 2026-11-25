--!native
--!optimize 2

local PathfindingService = game:GetService("PathfindingService")

local MovementStyles = require(script.MovementStyles)
local StateMachine = require(script.StateMachine)

local LOWEST_MAGNITUDE = 0.001
local FLAT = Vector3.new(1, 0, 1)
local LOS_CLEAR_INTERVAL = 2
local LOS_BLOCKED_INTERVAL = 0.5
local MAX_DIRECT_PITCH = math.rad(12)
local FACE_INTERVAL = 0.05
local MAX_PATHS_PER_SECOND = 12
local PATH_MAX_AGE = 5
local STUCK_TIME = 0.8
local STUCK_DISTANCE = 0.3
local TELEPORT_COOLDOWN = 4
local TELEPORT_LIMIT = 2
local WAYPOINT_SAFE_DISTANCE = 2
local TELEPORT_HEIGHT = 3
local GROUND_PROBE_LENGTH = 12
local UNSTUCK_TELEPORT_COOLDOWN = 6
local NO_PATH_TIMEOUT = 5
local TARGET_TELEPORT_COOLDOWN = 10
local TARGET_TELEPORT_DISTANCE = 4
local ARRIVED_RESUME_DISTANCE = 9

local JUMP_COOLDOWN = 1
local PUMA_MIN = 3
local PUMA_MAX = 10
local PUMA_DURATION = 0.25
local PUMA_COOLDOWN = 3
local LUNGE_DURATION = 0.3
local LUNGE_COOLDOWN = 2.5
local BAIT_DURATION = 0.4
local BAIT_COOLDOWN = 4
local SIDESTEP_DURATION = 0.25
local SIDESTEP_COOLDOWN = 1.5
local FLANK_DURATION = 2.5
local FLANK_LATERAL = 0.65

local pathBudget = 0
local budgetStart = 0

type MovementCallback = (
	controller: NavigationController,
	baseDirection: Vector3,
	dt: number,
	distance: number
) -> Vector3?

local MovementStyleConfigs: { [string]: MovementCallback } = {
	direct = function(_self: NavigationController, baseDirection)
		return baseDirection
	end,

	strafe = function(self: NavigationController, baseDirection, _dt, distance)
		local amplitude = 0.4 + 0.15 * math.clamp((distance - self.config.ReachDistance) / 12, 0, 1)
		return self:Sway(baseDirection, amplitude, 2.2)
	end,

	zigzag = function(self: NavigationController, baseDirection, _dt, distance)
		local amplitude = 0.4 + 0.2 * math.clamp((distance - self.config.ReachDistance) / 12, 0, 1)
		return self:Sway(baseDirection, amplitude, 1.8)
	end,

	flank = function(self: NavigationController, baseDirection, _dt, distance)
		if self.FlankSide == 0 then
			self.FlankSide = if self.StylePhase > math.pi then 1 else -1
			self.FlankAt = self.now
		end

		if
			self.now - self.FlankAt > FLANK_DURATION
			or distance <= self.config.ReachDistance + 6
		then
			return baseDirection
		end

		local result = baseDirection
			+ self:RightVector(baseDirection) * (self.FlankSide * FLANK_LATERAL)
		return result.Magnitude > LOWEST_MAGNITUDE and result.Unit or baseDirection
	end,

	bait = function(self: NavigationController, baseDirection, _dt, distance)
		local reach = self.config.ReachDistance
		local baitStart = reach + 10
		local baitEnd = reach + 20

		if distance >= baitEnd then
			self.StartBait = false
			return baseDirection
		end

		if distance <= baitStart and not self.StartBait then
			self.StartBait = true
			self:PulseJump()
			self:StartImpulse(-baseDirection, BAIT_DURATION, BAIT_COOLDOWN)
		end

		if self.StartBait then return self:ImpulseDirection(baseDirection) or -baseDirection end

		return baseDirection
	end,

	puma = function(self: NavigationController, baseDirection, _dt, distance)
		local impulse = self:ImpulseDirection(baseDirection)
		if impulse then return impulse end

		local reach = self.config.ReachDistance
		if
			self:IsDirect()
			and distance >= reach + PUMA_MIN
			and distance <= reach + PUMA_MAX
			and self:CanImpulse(PUMA_COOLDOWN)
		then
			self:PulseJump()
			self:StartImpulse(baseDirection, PUMA_DURATION, PUMA_COOLDOWN)
			return baseDirection
		end

		return self:Sway(baseDirection, 0.15, 1.2)
	end,

	lunge = function(self: NavigationController, baseDirection, _dt, distance)
		local impulse = self:ImpulseDirection(baseDirection)
		if impulse then return impulse end

		local reach = self.config.ReachDistance
		if
			self:IsDirect()
			and distance >= reach + 2
			and distance <= reach + 12
			and self:CanImpulse(LUNGE_COOLDOWN)
		then
			self:StartImpulse(baseDirection, LUNGE_DURATION, LUNGE_COOLDOWN)
			return baseDirection
		end

		return baseDirection
	end,

	orbit = function(self: NavigationController, baseDirection, _dt, distance)
		if self.FlankSide == 0 then self.FlankSide = if self.StylePhase > math.pi then 1 else -1 end

		local target = self.target
		local toward = baseDirection
		if target then
			local delta = (target.Position - self.rootPart.Position) * FLAT
			if delta.Magnitude > LOWEST_MAGNITUDE then toward = delta.Unit end
		end

		local hold = self.config.HoldDistance or self.config.ReachDistance
		local radial = toward * math.clamp((distance - hold) / 4, -1, 1) * 0.35
		local result = self:RightVector(toward) * self.FlankSide + radial

		return result.Magnitude > LOWEST_MAGNITUDE and result.Unit or baseDirection
	end,

	sidestep = function(self: NavigationController, baseDirection, _dt, distance)
		local impulse = self:ImpulseDirection(baseDirection)
		if impulse then return impulse end

		if self:IsDirect() and self:CanImpulse(SIDESTEP_COOLDOWN) then
			self.FlankSide = -self.FlankSide
			local side = if self.FlankSide == 0 then 1 else self.FlankSide
			self.FlankSide = side

			local direction = baseDirection + self:RightVector(baseDirection) * (side * 0.7)
			self:StartImpulse(direction.Unit, SIDESTEP_DURATION, SIDESTEP_COOLDOWN)
		end

		return self:Sway(baseDirection, 0.15, 1.4)
	end,
}

local DEFAULT_CONFIG: NavigationConfig = {
	ReachDistance = 4,
	ObstacleCheckDistance = 5,
	ObstacleCheckRadius = 5,
	PathRecalculateInterval = 3,
	PathRecalculateDistance = 15,
	AutoJump = true,
	MaxDirectPitch = MAX_DIRECT_PITCH,
	RotateToTarget = false,
	Style = MovementStyles.direct,
	Debug = false,
}

export type MovementStyle = MovementStyles.MovementStyle
export type StateMachine<T = { [string]: State }> = StateMachine.StateMachine<T>
export type State = StateMachine.State

export type NavigationConfig = {
	ReachDistance: number,
	HoldDistance: number?,

	ObstacleCheckDistance: number,
	ObstacleCheckRadius: number,

	PathRecalculateInterval: number,
	PathRecalculateDistance: number,

	AutoJump: boolean,
	MaxDirectPitch: number?,

	RotateToTarget: boolean?,
	Style: MovementStyle?,

	RayParams: RaycastParams?,

	Debug: boolean?,
}

type NavigationControllerMethods = {
	SetTarget: (self: NavigationController, target: BasePart) -> (),
	SetReachDistance: (self: NavigationController, distance: number) -> (),
	SetHoldDistance: (self: NavigationController, distance: number?) -> (),

	ClearTarget: (self: NavigationController) -> (),
	SetMovementStyle: (self: NavigationController, style: MovementStyle) -> (),

	Jump: (self: NavigationController) -> (),
	PulseJump: (self: NavigationController) -> (),
	CanImpulse: (self: NavigationController, cooldown: number) -> boolean,
	StartImpulse: (
		self: NavigationController,
		direction: Vector3,
		duration: number,
		cooldown: number
	) -> (),
	ImpulseDirection: (self: NavigationController, baseDirection: Vector3) -> Vector3?,
	IsDirect: (self: NavigationController) -> boolean,
	GetState: (self: NavigationController) -> string?,
	SideStep: (self: NavigationController, baseDirection: Vector3) -> Vector3,
	InvalidateLOS: (self: NavigationController) -> (),
	RightVector: (self: NavigationController, baseDirection: Vector3) -> Vector3,
	Sway: (
		self: NavigationController,
		baseDirection: Vector3,
		amplitude: number,
		frequency: number
	) -> Vector3,
	ResetStyleState: (self: NavigationController) -> (),
	Update: (self: NavigationController, dt: number, now: number) -> (),
	CheckStuck: (self: NavigationController, now: number) -> (),
	HandleStuck: (self: NavigationController, now: number) -> (),
	TeleportTo: (self: NavigationController, position: Vector3) -> (),
	TeleportNearTarget: (self: NavigationController, force: boolean?) -> (),
	MoveInDirection: (self: NavigationController, direction: Vector3?) -> (),
	FaceTarget: (self: NavigationController, pos: Vector3, targetPos: Vector3) -> (),
	HasLineOfSight: (
		self: NavigationController,
		from: Vector3,
		to: Vector3,
		force: boolean?
	) -> (boolean, RaycastResult?),
	UpdatePathfinding: (
		self: NavigationController,
		from: Vector3,
		to: Vector3,
		dt: number
	) -> (),
	VisualizePath: (self: NavigationController, path: Path?) -> (),
	GetBaseDirection: (self: NavigationController, from: Vector3, to: Vector3) -> Vector3,

	DisableRotation: (self: NavigationController) -> (),
	EnableRotation: (self: NavigationController) -> (),

	Destroy: (self: NavigationController) -> (),
}

type NavigatorState = StateMachine.State & { navigator: NavigationController }

local States = {
	Idle = {
		Enter = function(self: NavigatorState)
			self.navigator.humanoid:Move(Vector3.zero)
			self.navigator.alignOrient.Enabled = self.navigator.config.RotateToTarget
				and not self.navigator.RotationSuppressed
		end,

		Update = function(self: NavigatorState, _dt: number)
			local navigator = self.navigator
			local target = navigator.target
			if not target or not target.Parent then
				navigator:ClearTarget()
				return
			end

			local pos = navigator.rootPart.Position
			local targetPos = target.Position
			local dist = (pos - targetPos).Magnitude

			navigator:FaceTarget(pos, targetPos)
			navigator.alignOrient.Enabled = not navigator.humanoid.PlatformStand
				and not navigator.RotationSuppressed

			local hasLOS = navigator:HasLineOfSight(pos, targetPos)

			if navigator.config.HoldDistance then
				navigator.stateMachine:ChangeState(if hasLOS then "HoldingDistance" else "Direct")
				return
			end

			if navigator.config.ReachDistance then
				if hasLOS then
					if dist <= navigator.config.ReachDistance then return end

					navigator.stateMachine:ChangeState("Direct")
				else
					navigator.stateMachine:ChangeState("Pathfinding")
				end
			end
		end,
	},

	Direct = {
		Enter = function(self: NavigatorState)
			local navigator = self.navigator
			navigator.alignOrient.Enabled = navigator.config.RotateToTarget
				and not navigator.RotationSuppressed

			if navigator.path then
				navigator.path = nil
				table.clear(navigator.waypoints)
				navigator.waypoint = 0
			end
		end,

		Update = function(self: NavigatorState, dt: number)
			local navigator = self.navigator
			local target = navigator.target
			if not target then return end

			local pos = navigator.rootPart.Position
			local targetPos = target.Position
			local dist = (pos - targetPos).Magnitude

			navigator:FaceTarget(pos, targetPos)
			navigator.alignOrient.Enabled = not navigator.humanoid.PlatformStand
				and not navigator.RotationSuppressed

			if not navigator.config.ReachDistance then
				navigator.stateMachine:ChangeState("Idle")
				return
			end

			local hasLOS = navigator:HasLineOfSight(pos, targetPos)

			if
				hasLOS
				and navigator.config.HoldDistance
				and dist < navigator.config.HoldDistance
			then
				navigator.stateMachine:ChangeState("HoldingDistance")
				return
			end

			if dist <= navigator.config.ReachDistance then
				if navigator.config.HoldDistance and hasLOS then
					navigator.stateMachine:ChangeState("HoldingDistance")
				else
					navigator.humanoid:Move(Vector3.zero)
				end
				return
			end

			if hasLOS then
				local baseDirection = navigator:GetBaseDirection(pos, targetPos)
				local styleCallback = MovementStyleConfigs[navigator.config.Style]
				navigator:MoveInDirection(
					if styleCallback
						then styleCallback(navigator, baseDirection, dt, dist)
						else baseDirection
				)
			else
				navigator.stateMachine:ChangeState("Pathfinding")
			end
		end,
	},

	HoldingDistance = {
		Enter = function(self: NavigatorState)
			self.navigator.alignOrient.Enabled = self.navigator.config.RotateToTarget
				and not self.navigator.RotationSuppressed
		end,

		Update = function(self: NavigatorState, dt: number)
			local navigator = self.navigator
			local target = navigator.target
			if not target then return end

			local pos = navigator.rootPart.Position
			local targetPos = target.Position
			local dist = (pos - targetPos).Magnitude

			navigator:FaceTarget(pos, targetPos)
			navigator.alignOrient.Enabled = not navigator.humanoid.PlatformStand
				and not navigator.RotationSuppressed

			if not navigator.config.HoldDistance then
				navigator.stateMachine:ChangeState("Idle")
				return
			end

			local hasLOS = navigator:HasLineOfSight(pos, targetPos)
			if not hasLOS then
				navigator.stateMachine:ChangeState("Pathfinding")
				return
			end

			if dist > navigator.config.HoldDistance + 10 then
				navigator.stateMachine:ChangeState("Direct")
				return
			end

			if dist >= navigator.config.HoldDistance then
				navigator.humanoid:Move(Vector3.zero)
				return
			end

			local baseDirection = navigator:GetBaseDirection(
				targetPos,
				(pos - targetPos).Unit * navigator.config.HoldDistance
			)
			local styleCallback = MovementStyleConfigs[navigator.config.Style]
			navigator:MoveInDirection(
				if styleCallback
					then styleCallback(navigator, baseDirection, dt, dist)
					else baseDirection
			)
		end,
	},

	Arrived = {
		Enter = function(self: NavigatorState)
			local navigator = self.navigator
			navigator.humanoid:Move(Vector3.zero)
			navigator.alignOrient.Enabled = navigator.config.RotateToTarget
				and not navigator.RotationSuppressed
		end,

		Update = function(self: NavigatorState, _dt: number)
			local navigator = self.navigator
			local target = navigator.target
			if not target or not target.Parent then
				navigator:ClearTarget()
				return
			end

			local pos = navigator.rootPart.Position
			local targetPos = target.Position
			navigator:FaceTarget(pos, targetPos)
			navigator.alignOrient.Enabled = not navigator.humanoid.PlatformStand
				and not navigator.RotationSuppressed

			if (pos - targetPos).Magnitude > ARRIVED_RESUME_DISTANCE then
				navigator.stateMachine:ChangeState(
					if navigator:HasLineOfSight(pos, targetPos) then "Direct" else "Pathfinding"
				)
				return
			end

			navigator.humanoid:Move(Vector3.zero)
		end,
	},

	Pathfinding = {
		Enter = function(self: NavigatorState)
			local navigator = self.navigator
			navigator.pathWaitAt = navigator.now
			navigator.alignOrient.Enabled = navigator.config.RotateToTarget
				and not navigator.RotationSuppressed
		end,

		Update = function(self: NavigatorState, dt: number)
			local navigator = self.navigator
			local target = navigator.target
			if not target then return end

			local pos = navigator.rootPart.Position
			local targetPos = target.Position

			navigator:FaceTarget(pos, targetPos)
			navigator.alignOrient.Enabled = not navigator.humanoid.PlatformStand
				and not navigator.RotationSuppressed

			local hasValidPath = navigator.path
				and navigator.waypoint
				and navigator.waypoint > 0
				and navigator.waypoint <= #navigator.waypoints

			if hasValidPath then
				navigator.alignOrient.Enabled = false
				navigator.stateMachine:ChangeState("FollowingPath")
				return
			end

			navigator:UpdatePathfinding(pos, targetPos, dt)

			if
				navigator.now - navigator.pathWaitAt >= NO_PATH_TIMEOUT
				and navigator.now - navigator.targetTeleportAt >= TARGET_TELEPORT_COOLDOWN
			then
				navigator:TeleportNearTarget()
			end

			navigator:MoveInDirection(navigator:GetBaseDirection(pos, targetPos))
		end,
	},

	FollowingPath = {
		Enter = function(self: NavigatorState)
			self.navigator.alignOrient.Enabled = false
			self.navigator.waypoint = 1
		end,

		Update = function(self: NavigatorState, _dt: number)
			local navigator = self.navigator
			local target = navigator.target
			if not target then return end

			local pos = navigator.rootPart.Position
			local targetPos = target.Position

			local currentWaypoint = navigator.waypoints[navigator.waypoint]
			if not currentWaypoint then
				navigator.stateMachine:ChangeState("Arrived")
				return
			end

			local waypointPos = currentWaypoint.Position
			local distToWaypoint = (waypointPos * FLAT - pos * FLAT).Magnitude

			navigator.humanoid:Move((waypointPos - pos).Unit)

			if
				currentWaypoint.Action == Enum.PathWaypointAction.Jump
				and navigator.config.AutoJump
			then
				navigator:Jump()
			end

			if navigator.now - navigator.lastLosTime >= 0.25 then
				local hasLOS = navigator:HasLineOfSight(pos, targetPos, true)
				if hasLOS then
					if navigator.ClearStreak >= 2 then
						navigator.stateMachine:ChangeState("Direct")
						return
					end
				else
					navigator.ClearStreak = 0
				end
			end

			if distToWaypoint < (navigator.humanoid.WalkSpeed / 16) then
				local remaining = #navigator.waypoints - navigator.waypoint
				navigator.waypoint += math.max(1, math.floor(remaining / 2))
				if navigator.waypoint > #navigator.waypoints then
					navigator.stateMachine:ChangeState("Arrived")
				end
			end
		end,

		Exit = function(self: NavigatorState)
			local navigator = self.navigator
			if navigator.path then
				navigator.path = nil
				table.clear(navigator.waypoints)
				navigator.waypoint = 0
			end
		end,
	},
}

type NavigationControllerProperties = {
	stateMachine: StateMachine.StateMachine<typeof(States)>,
	config: NavigationConfig,
	target: BasePart?,

	agentParams: {},
	rayParams: RaycastParams,

	rig: Model,
	rootPart: BasePart,
	humanoid: Humanoid,

	path: Path?,
	lastCalcPathTime: number?,
	lastTargetPos: Vector3?,

	waypoints: { PathWaypoint },
	waypoint: number?,

	isComputingPath: boolean?,

	alignOrient: AlignOrientation,
	rotateAttach: Attachment,

	RotationSuppressed: boolean,
	StartBait: boolean?,

	StylePhase: number,
	LastJump: number,
	LastImpulse: number,
	ImpulseUntil: number,
	ImpulseDir: Vector3?,
	FlankSide: number,
	FlankAt: number,

	now: number,
	lastLosTime: number,
	losResult: RaycastResult?,
	losClear: boolean,
	ClearStreak: number,
	pathCreatedAt: number,
	samplePos: Vector3?,
	sampleAt: number,
	stuckLevel: number,
	teleportCount: number,
	teleportAt: number,
	pathWaitAt: number,
	targetTeleportAt: number,
	unstuckTeleportAt: number,
	teleportPending: boolean,
	lastFaceTime: number,
	lastFacePos: Vector3?,
}

export type NavigationController = NavigationControllerProperties & NavigationControllerMethods

local NavigationController = {}
NavigationController.__index = NavigationController

function NavigationController:Update(dt: number, now: number)
	self.now = now
	self.stateMachine:Update(dt)
	self:CheckStuck(now)
end

function NavigationController.Jump(self: NavigationController)
	self.humanoid.Jump = true
	task.defer(function()
		if self.humanoid.Parent then self.humanoid.Jump = false end
	end)
end

function NavigationController:PulseJump()
	if self.now - self.LastJump < JUMP_COOLDOWN then return end
	if self.humanoid.FloorMaterial == Enum.Material.Air then return end

	self.LastJump = self.now
	self:Jump()
end

function NavigationController:CanImpulse(cooldown: number): boolean
	return self.now - self.LastImpulse >= cooldown
end

function NavigationController:StartImpulse(direction: Vector3, duration: number, cooldown: number)
	self.LastImpulse = self.now
	self.ImpulseUntil = self.now + duration
	self.ImpulseDir = direction
end

function NavigationController:ImpulseDirection(baseDirection: Vector3): Vector3?
	if self.now >= self.ImpulseUntil then return nil end

	return self.ImpulseDir or baseDirection
end

function NavigationController:IsDirect(): boolean
	return self.stateMachine:GetCurrent() == "Direct"
end

function NavigationController:GetState(): string?
	return self.stateMachine:GetCurrent()
end

function NavigationController:InvalidateLOS()
	self.lastLosTime = -math.huge
	self.ClearStreak = 0
end

function NavigationController:SideStep(baseDirection: Vector3): Vector3
	return self:RightVector(baseDirection) * math.sin(self.now * 2.5 + self.StylePhase)
end

function NavigationController:RightVector(baseDirection: Vector3): Vector3
	return Vector3.new(-baseDirection.Z, 0, baseDirection.X)
end

function NavigationController:Sway(
	baseDirection: Vector3,
	amplitude: number,
	frequency: number
): Vector3
	local result = baseDirection
		+ self:RightVector(baseDirection)
			* (math.sin(self.now * frequency + self.StylePhase) * amplitude)

	return result.Magnitude > LOWEST_MAGNITUDE and result.Unit or baseDirection
end

function NavigationController:ResetStyleState()
	self.LastImpulse = -math.huge
	self.ImpulseUntil = -math.huge
	self.ImpulseDir = nil
	self.FlankSide = 0
	self.FlankAt = -math.huge
	self.StartBait = false
	self.samplePos = nil
	self.sampleAt = self.now
	self.stuckLevel = 0
end

function NavigationController.MoveInDirection(self: NavigationController, direction: Vector3?)
	if not direction or direction.Magnitude < LOWEST_MAGNITUDE then
		self.humanoid:Move(Vector3.zero)
		return
	end

	self.humanoid:Move(direction)
end

function NavigationController:HandleStuck(now: number)
	self:InvalidateLOS()

	local total = #self.waypoints
	local current = self.waypoint
	local target = self.target

	-- Jump to the midpoint of the points that are still ahead, not to the
	-- midpoint of the whole path: the bot may already have walked half of it.
	local index: number? = nil
	if current and total > 0 and current <= total then
		local remaining = total - current
		index = current + math.max(1, math.floor(remaining / 2))
		if index > total then index = total end
	end

	local waypoint = index and self.waypoints[index]
	local safe = waypoint
		and (
			not target
			or (waypoint.Position - target.Position).Magnitude >= WAYPOINT_SAFE_DISTANCE
		)
	local canTeleport = safe
		and now - self.teleportAt >= TELEPORT_COOLDOWN
		and self.teleportCount < TELEPORT_LIMIT

	if self.stuckLevel == 0 and index and waypoint and canTeleport then
		self.stuckLevel = 1
		self.teleportAt = now
		self.teleportCount += 1
		self.teleportPending = true

		self:TeleportTo(waypoint.Position + Vector3.yAxis * TELEPORT_HEIGHT)
		self.waypoint = index + 1
		self.samplePos = self.rootPart.Position
		self.sampleAt = now
		self:InvalidateLOS()
		return
	end

	if self.stuckLevel == 0 then
		self.stuckLevel = 1
		self.path = nil
		table.clear(self.waypoints)
		self.waypoint = 0
		self.lastCalcPathTime = -math.huge
		self.pathCreatedAt = -math.huge
		self.stateMachine:ChangeState("Pathfinding")
		return
	end

	self:Jump()
	self.stuckLevel = 0
	self.lastCalcPathTime = -math.huge
end

function NavigationController:TeleportTo(position: Vector3)
	local origin = position + Vector3.yAxis * 4
	local result = workspace:Raycast(origin, Vector3.yAxis * -GROUND_PROBE_LENGTH, self.rayParams)
	local destination = if result then result.Position + Vector3.yAxis else position

	self.rig:PivotTo(CFrame.new(destination))
	self.rootPart.AssemblyLinearVelocity = Vector3.zero
	self.rootPart.AssemblyAngularVelocity = Vector3.zero
end

function NavigationController:TeleportNearTarget(_force: boolean?)
	local target = self.target
	if not target then return end

	self.targetTeleportAt = self.now
	self.teleportPending = false

	local direction = (self.rootPart.Position - target.Position) * FLAT
	if direction.Magnitude < LOWEST_MAGNITUDE then
		direction = self.rootPart.CFrame.LookVector * FLAT
	end
	if direction.Magnitude < LOWEST_MAGNITUDE then return end

	local destination = target.Position
		+ direction.Unit * TARGET_TELEPORT_DISTANCE
		+ Vector3.yAxis * TELEPORT_HEIGHT

	self:TeleportTo(destination)
	self.samplePos = self.rootPart.Position
	self.sampleAt = self.now

	self.path = nil
	table.clear(self.waypoints)
	self.waypoint = 0
	self.lastCalcPathTime = -math.huge
	self.pathCreatedAt = -math.huge
	self.pathWaitAt = self.now
	self:InvalidateLOS()
	self.stateMachine:ChangeState("Direct")
end

function NavigationController:CheckStuck(now: number)
	local state = self.stateMachine:GetCurrent()

	if state ~= "Direct" and state ~= "Pathfinding" and state ~= "FollowingPath" then
		self.samplePos = nil
		self.sampleAt = now
		self.stuckLevel = 0
		return
	end

	local target = self.target
	if not target then return end

	local pos = self.rootPart.Position
	if state == "Direct" and (target.Position - pos).Magnitude <= self.config.ReachDistance then
		self.samplePos = nil
		self.sampleAt = now
		return
	end

	if not self.samplePos then
		self.samplePos = pos
		self.sampleAt = now
		return
	end

	if now - self.sampleAt < STUCK_TIME then return end

	local moved = (pos - self.samplePos).Magnitude
	self.samplePos = pos
	self.sampleAt = now

	if moved >= STUCK_DISTANCE then
		self.stuckLevel = 0
		self.teleportPending = false
		return
	end

	if self.teleportPending and now - self.unstuckTeleportAt >= UNSTUCK_TELEPORT_COOLDOWN then
		self.teleportPending = false
		self.unstuckTeleportAt = now
		self:TeleportNearTarget(true)
		return
	end

	self:HandleStuck(now)
end

function NavigationController.FaceTarget(
	self: NavigationController,
	pos: Vector3,
	targetPos: Vector3
)
	if self.now - self.lastFaceTime < FACE_INTERVAL then return end
	if self.lastFacePos and (self.lastFacePos - targetPos).Magnitude < 0.1 then return end

	self.lastFaceTime = self.now
	self.lastFacePos = targetPos

	self.alignOrient.CFrame = CFrame.lookAt(pos, targetPos * FLAT + Vector3.yAxis * pos.Y)
end

function NavigationController.HasLineOfSight(
	self: NavigationController,
	from: Vector3,
	to: Vector3,
	force: boolean?
): (boolean, RaycastResult?)
	local interval = if self.losClear then LOS_CLEAR_INTERVAL else LOS_BLOCKED_INTERVAL
	if not force and self.now - self.lastLosTime < interval then
		return self.losClear, self.losResult
	end

	self.lastLosTime = self.now

	local direction = to - from
	local distance = direction.Magnitude

	-- A clear ray is not a walkable route: a steep ray means the target sits on
	-- a ledge or a pyramid, where direct movement just oscillates.
	local flat = Vector3.new(direction.X, 0, direction.Z).Magnitude
	local pitch = math.atan2(math.abs(direction.Y), flat)
	if pitch > (self.config.MaxDirectPitch or MAX_DIRECT_PITCH) then
		self.losClear = false
		self.losResult = nil
		self.ClearStreak = 0
		return false, nil
	end

	local result: RaycastResult? =
		workspace:Raycast(from, direction.Unit * distance, self.rayParams)

	local clear = true
	if result and self.target then
		if result.Instance == self.target then
			result = nil
		else
			local targetModel = self.target:FindFirstAncestorOfClass("Model")
			if targetModel and result.Instance:IsDescendantOf(targetModel) then result = nil end
		end
	end

	if result then clear = false end

	self.losClear = clear
	self.losResult = result
	self.ClearStreak = if clear then self.ClearStreak + 1 else 0

	return clear, result
end

function NavigationController.UpdatePathfinding(
	self: NavigationController,
	from: Vector3,
	to: Vector3,
	_deltaTime: number
)
	if self.isComputingPath then return end

	local now = os.clock()
	if now - budgetStart >= 1 then
		budgetStart = now
		pathBudget = 0
	end
	if pathBudget >= MAX_PATHS_PER_SECOND then return end

	local timeSinceLastCalc = tick() - (self.lastCalcPathTime or 0)
	if timeSinceLastCalc < self.config.PathRecalculateInterval then return end

	local pathFinished = self.path and self.waypoint and self.waypoint > #self.waypoints
	local targetMoved = self.lastTargetPos
		and (to - self.lastTargetPos).Magnitude > self.config.PathRecalculateDistance
	local pathExpired = self.path and self.now - self.pathCreatedAt > PATH_MAX_AGE

	if self.path and not pathFinished and not targetMoved and not pathExpired then return end

	self.isComputingPath = true
	self.lastCalcPathTime = tick()
	pathBudget += 1

	task.spawn(function()
		local success, path = pcall(function()
			local newPath = PathfindingService:CreatePath(self.agentParams)
			newPath:ComputeAsync(from, to)
			return newPath
		end)

		self.isComputingPath = false

		if success and path and path.Status == Enum.PathStatus.Success then
			self.path = path
			self.waypoint = 1
			self.waypoints = path:GetWaypoints()
			self.lastTargetPos = to
			self.pathCreatedAt = self.now
			self.teleportCount = 0
			self.stuckLevel = 0

			if self.config.Debug then self:VisualizePath(path) end
		else
			self.path = nil
			table.clear(self.waypoints)
			self.waypoint = 0
		end
	end)
end

function NavigationController.VisualizePath(_self: NavigationController, path: Path?)
	if not path then return end

	for _, waypoint in path:GetWaypoints() do
		local part = Instance.new("Part")
		part.Size = Vector3.new(1, 1, 1)
		part.Anchored = true
		part.CanCollide = false
		part.Material = Enum.Material.Neon
		part.Position = waypoint.Position
		part.Parent = workspace
		game.Debris:AddItem(part, 10)
	end
end

function NavigationController:GetBaseDirection(from: Vector3, to: Vector3): Vector3
	local direction = (to - from) * FLAT

	if direction.Magnitude < LOWEST_MAGNITUDE then return self.rootPart.CFrame.LookVector end

	return direction.Unit
end

function NavigationController.SetTarget(self: NavigationController, target: BasePart)
	if self.target == target then return end

	self.target = target
	self.lastTargetPos = target.Position
	self.pathCreatedAt = -math.huge
	self.teleportCount = 0
	self.teleportAt = -math.huge
	self.targetTeleportAt = -math.huge
	self.unstuckTeleportAt = -math.huge
	self.teleportPending = false
	self:ResetStyleState()
	self.lastLosTime = -math.huge
	self.lastFaceTime = -math.huge
	self.lastFacePos = nil

	self.stateMachine:ChangeState("Idle")
end

function NavigationController.ClearTarget(self: NavigationController)
	self.stateMachine:ChangeState("None")

	self.target = nil
	self.pathCreatedAt = -math.huge
	self.teleportCount = 0
	self.teleportAt = -math.huge
	self.targetTeleportAt = -math.huge
	self.unstuckTeleportAt = -math.huge
	self.teleportPending = false
	self:ResetStyleState()
	self.lastLosTime = -math.huge
	self.humanoid:Move(Vector3.zero)
	self.alignOrient.Enabled = false

	if self.config.Debug then print("Target cleared") end
end

function NavigationController.SetMovementStyle(self: NavigationController, style: MovementStyle)
	self.config.Style = style
	self:ResetStyleState()
end

function NavigationController.Destroy(self: NavigationController)
	self:ClearTarget()

	self.alignOrient:Destroy()
	self.rotateAttach:Destroy()
	self.stateMachine:Destroy()
end

function NavigationController.DisableRotation(self: NavigationController)
	self.RotationSuppressed = true
	self.alignOrient.Enabled = false
end

function NavigationController.EnableRotation(self: NavigationController)
	self.RotationSuppressed = false
end

function NavigationController.SetReachDistance(self: NavigationController, distance: number)
	self.config.ReachDistance = math.max(0, distance)
end

function NavigationController.SetHoldDistance(self: NavigationController, distance: number?)
	self.config.HoldDistance = distance
end

return {
	new = function(rig: Model, config: NavigationConfig?): NavigationController
		if config then
			for i, v in DEFAULT_CONFIG do
				if config[i] == nil then config[i] = v end
			end
		end

		local root = rig.PrimaryPart or rig:FindFirstChild("HumanoidRootPart")
		if not root then
			error("NavigationController rig must have a PrimaryPart or HumanoidRootPart")
		end

		local humanoid = rig:FindFirstChildOfClass("Humanoid")
		if not humanoid then error("NavigationController rig must have a Humanoid") end

		local agentParams = {
			AgentRadius = config and config.ObstacleCheckRadius or 5,
			AgentHeight = rig:GetExtentsSize().Y,
			AgentCanJump = config and config.AutoJump or false,
			AgentCanClimb = true,
			WaypointSpacing = 10,
		}

		local rayParams = config and config.RayParams

		if not rayParams then
			rayParams = RaycastParams.new()
			rayParams.RespectCanCollide = true
			rayParams.IgnoreWater = true
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			rayParams:AddToFilter(rig)
		end

		local rotateAttachment = Instance.new("Attachment")
		rotateAttachment.Name = "RotateAttachment"
		rotateAttachment.Parent = root

		local alignOrientation = Instance.new("AlignOrientation")
		alignOrientation.Name = "RotateToTarget"
		alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		alignOrientation.Attachment0 = rotateAttachment
		alignOrientation.Enabled = false
		alignOrientation.RigidityEnabled = true
		alignOrientation.Parent = root

		local navigator = setmetatable(
			{
				config = config or table.clone(DEFAULT_CONFIG),
				stateMachine = StateMachine.new({ CreateNoneState = true }),

				agentParams = agentParams,
				rayParams = rayParams,

				waypoints = {},
				waypoint = 0,
				lastCalcPathTime = 0,
				lastTargetPos = nil,

				rig = rig,
				rootPart = root,
				humanoid = humanoid,

				alignOrient = alignOrientation,
				rotateAttach = rotateAttachment,

				RotationSuppressed = false,
				StartBait = false,

				StylePhase = Random.new():NextNumber(0, math.pi * 2),
				LastJump = -math.huge,
				LastImpulse = -math.huge,
				ImpulseUntil = -math.huge,
				ImpulseDir = nil,
				FlankSide = 0,
				FlankAt = -math.huge,

				now = 0,
				lastLosTime = -math.huge,
				losResult = nil,
				losClear = true,
				ClearStreak = 0,
				pathCreatedAt = -math.huge,
				samplePos = nil,
				sampleAt = 0,
				stuckLevel = 0,
				teleportCount = 0,
				teleportAt = -math.huge,
				pathWaitAt = -math.huge,
				targetTeleportAt = -math.huge,
				unstuckTeleportAt = -math.huge,
				teleportPending = false,
				lastFaceTime = -math.huge,
				lastFacePos = nil,
			} :: NavigationController,
			NavigationController
		) :: NavigationController

		for name, state in States do
			local copy = table.clone(state)
			copy["navigator"] = navigator
			navigator.stateMachine:AddState(name, copy)
		end

		return navigator
	end,

	MovementStyles = MovementStyles,
	StateMachine = StateMachine,
}
