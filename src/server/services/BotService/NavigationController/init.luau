--!native
--!optimize 2

local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local MovementStyles = require(script.MovementStyles)
local StateMachine = require(script.StateMachine)

const LOWEST_MAGNITUDE = 0.001

local function VisualizePath(path: Path): ()
	if not path then return end
	local nodes = path:GetWaypoints()

	for i, waypoint: PathWaypoint in ipairs(nodes) do
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

local MovementStyleConfigs: { [string]: MovementCallback } = {
	direct = function(self: NavigationController, baseDirection, dt, distance)
		return baseDirection
	end,

	strafe = function(self: NavigationController, baseDirection, dt, distance)
		local right = Vector3.new(-baseDirection.Z, 0, baseDirection.X)
		local time = tick()

		local strafeAmount = math.sin(time * 2.5) * 0.8
		local result = baseDirection + right * strafeAmount

		if result.Magnitude > LOWEST_MAGNITUDE then return result.Unit end
		return baseDirection
	end,

	zigzag = function(self: NavigationController, baseDirection, dt, distance)
		local right = Vector3.new(-baseDirection.Z, 0, baseDirection.X)

		local zigzagAmount = math.sin(tick() * 2) * 2
		local result = baseDirection + right * zigzagAmount

		if result.Magnitude > LOWEST_MAGNITUDE then return result.Unit end

		return baseDirection
	end,

	flank = function(self: NavigationController, baseDirection, dt, distance)
		local right = Vector3.new(-baseDirection.Z, 0, baseDirection.X)

		--local hash = math.noise(self.rootPart.Position.X * 0.03, 0, self.rootPart.Position.Z * 0.03)
		--local side = hash > 0 and 1 or -1

		--local blend = math.clamp(distance / 30, 0.3, 1)
		--local result = baseDirection * (1 - blend * 0.5) + right * blend * side

		--if result.Magnitude > LOWEST_MAGNITUDE then
		--	return result.Unit
		--end
		return baseDirection
	end,

	bait = function(self: NavigationController, baseDirection, dt, distance)
		local reachDist = self.config.ReachDistance or 4
		local baitStart = reachDist + 10
		local baitEnd = reachDist + 20

		if distance >= baitEnd then
			self.StartBait = false
			return baseDirection
		end

		if self.StartBait and distance < baitEnd then
			self:Jump()
			return -baseDirection
		end

		if distance <= baitStart then
			self.StartBait = true
			return -baseDirection
		end

		return baseDirection
	end,

	puma = function(self: NavigationController, baseDirection, dt, distance)
		if
			distance < 15 + self.config.ReachDistance
			and distance > 2 + self.config.ReachDistance
		then
			self:Jump()
		end

		return baseDirection
	end,
}

const DEFAULT_CONFIG: NavigationConfig = {
	ReachDistance = 4,
	ObstacleCheckDistance = 5,
	ObstacleCheckRadius = 5,
	PathRecalculateInterval = 3,
	PathRecalculateDistance = 15,
	AutoJump = true,
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

	Destroy: (self: NavigationController) -> (),
}

type NavigatorState = StateMachine.State & { navigator: NavigationController }

local States = {
	Idle = {
		Enter = function(self: NavigatorState)
			self.navigator.humanoid:Move(Vector3.zero)
			self.navigator.alignOrient.Enabled = self.navigator.config.RotateToTarget
		end,

		Update = function(self: NavigatorState, dt: number)
			if not self.navigator.target or not self.navigator.target.Parent then
				self.navigator:ClearTarget()
				return
			end

			local target = self.navigator.target
			local pos = self.navigator.rootPart.Position
			local targetPos = target.Position
			local dist = (pos - targetPos).Magnitude

			self.navigator.alignOrient.CFrame =
				CFrame.lookAt(pos, targetPos * Vector3.new(1, 0, 1) + Vector3.yAxis * pos.Y)

			self.navigator.alignOrient.Enabled = not self.navigator.humanoid.PlatformStand

			local hasLOS: boolean, result: RaycastResult =
				self.navigator:HasLineOfSight(pos, targetPos)

			if self.navigator.config.HoldDistance then
				if hasLOS then
					self.navigator.stateMachine:ChangeState("HoldingDistance")
				else
					self.navigator.stateMachine:ChangeState("Direct")
				end

				return
			end

			if self.navigator.config.ReachDistance then
				if
					hasLOS
					or (
						(result.Position - pos).Magnitude
						> self.navigator.config.ObstacleCheckDistance
					)
				then
					if dist <= self.navigator.config.ReachDistance then return end

					self.navigator.stateMachine:ChangeState("Direct")
				else
					self.navigator.stateMachine:ChangeState("Pathfinding")
				end
			end
		end,
	},

	Direct = {
		Enter = function(self: NavigatorState)
			self.navigator.alignOrient.Enabled = self.navigator.config.RotateToTarget

			if self.navigator.path then
				self.navigator.path = nil
				table.clear(self.navigator.waypoints)
				self.navigator.waypoint = 0
			end
		end,

		Update = function(self: NavigatorState, dt: number)
			local target = self.navigator.target
			local pos = self.navigator.rootPart.Position
			local targetPos = target.Position
			local dist = (pos - targetPos).Magnitude

			self.navigator.alignOrient.Enabled = not self.navigator.humanoid.PlatformStand

			self.navigator.alignOrient.CFrame =
				CFrame.lookAt(pos, targetPos * Vector3.new(1, 0, 1) + Vector3.yAxis * pos.Y)

			if not self.navigator.config.ReachDistance then
				self.navigator.stateMachine:ChangeState("Idle")
				return
			end

			local hasLOS: boolean, result: RaycastResult =
				self.navigator:HasLineOfSight(pos, targetPos)

			if
				hasLOS
				and self.navigator.config.HoldDistance
				and dist < self.navigator.config.HoldDistance
			then
				self.navigator.stateMachine:ChangeState("HoldingDistance")
				return
			end

			if dist <= self.navigator.config.ReachDistance then
				if self.navigator.config.HoldDistance and hasLOS then
					self.navigator.stateMachine:ChangeState("HoldingDistance")
					return
				else
					self.navigator.humanoid:Move(Vector3.zero)
					return
				end
			end

			if
				hasLOS
				or ((result.Position - pos).Magnitude > self.navigator.config.ObstacleCheckDistance)
			then
				local baseDirection = self.navigator:GetBaseDirection(pos, targetPos)
				local styleCallback = MovementStyleConfigs[self.navigator.config.Style]
				local finalDirection = baseDirection
				if styleCallback then
					finalDirection = styleCallback(self.navigator, baseDirection, dt, dist)
				end

				self.navigator:MoveInDirection(finalDirection)
			else
				self.navigator.stateMachine:ChangeState("Pathfinding")
			end
		end,
	},

	HoldingDistance = {
		Enter = function(self: NavigatorState)
			self.navigator.alignOrient.Enabled = self.navigator.config.RotateToTarget
		end,

		Update = function(self: NavigatorState, dt: number)
			local target = self.navigator.target
			local pos = self.navigator.rootPart.Position
			local targetPos = target.Position
			local dist = (pos - targetPos).Magnitude

			self.navigator.alignOrient.CFrame =
				CFrame.lookAt(pos, targetPos * Vector3.new(1, 0, 1) + Vector3.yAxis * pos.Y)

			self.navigator.alignOrient.Enabled = not self.navigator.humanoid.PlatformStand

			if not self.navigator.config.HoldDistance then
				self.navigator.stateMachine:ChangeState("Idle")
				return
			end

			local hasLOS: boolean, result: RaycastResult =
				self.navigator:HasLineOfSight(pos, targetPos)

			if not hasLOS then
				self.navigator.stateMachine:ChangeState("Pathfinding")
				return
			end

			if dist > self.navigator.config.HoldDistance + 10 then
				self.navigator.stateMachine:ChangeState("Direct")
				return
			end

			if dist >= self.navigator.config.HoldDistance then
				self.navigator.humanoid:Move(Vector3.zero)
				return
			end

			local baseDirection = self.navigator:GetBaseDirection(
				targetPos,
				(pos - targetPos).Unit * self.navigator.config.HoldDistance
			) -- switched direction
			local styleCallback = MovementStyleConfigs[self.navigator.config.Style]
			local finalDirection = baseDirection

			if styleCallback then
				finalDirection = styleCallback(self.navigator, baseDirection, dt, dist)
			end

			self.navigator:MoveInDirection(finalDirection)
		end,
	},

	Pathfinding = {
		Enter = function(self: NavigatorState)
			self.navigator.alignOrient.Enabled = self.navigator.config.RotateToTarget
		end,

		Update = function(self: NavigatorState, dt: number)
			local target = self.navigator.target
			local pos = self.navigator.rootPart.Position
			local targetPos = target.Position
			local dist = (pos - targetPos).Magnitude

			self.navigator.alignOrient.CFrame =
				CFrame.lookAt(pos, targetPos * Vector3.new(1, 0, 1) + Vector3.yAxis * pos.Y)

			self.navigator.alignOrient.Enabled = not self.navigator.humanoid.PlatformStand

			local hasValidPath = self.navigator.path
				and self.navigator.waypoint
				and self.navigator.waypoint > 0
				and self.navigator.waypoint <= #self.navigator.waypoints

			if hasValidPath then
				self.navigator.alignOrient.Enabled = false
				self.navigator.stateMachine:ChangeState("FollowingPath")
			else
				self.navigator:UpdatePathfinding(pos, targetPos, dt)

				local baseDirection = self.navigator:GetBaseDirection(pos, targetPos)
				local styleCallback = MovementStyleConfigs[self.navigator.config.Style]
				local finalDirection = baseDirection
				if styleCallback then
					finalDirection = styleCallback(self.navigator, baseDirection, dt, dist)
				end

				self.navigator:MoveInDirection(finalDirection)
			end
		end,
	},

	FollowingPath = {
		Enter = function(self: NavigatorState)
			self.navigator.alignOrient.Enabled = false
			self.navigator.waypoint = 1
		end,

		Update = function(self: NavigatorState, dt: number)
			local target = self.navigator.target
			local pos = self.navigator.rootPart.Position
			local targetPos = target.Position
			local dist = (pos - targetPos).Magnitude

			local currentWaypoint = self.navigator.waypoints[self.navigator.waypoint]
			local waypointPos = currentWaypoint.Position
			local distToWaypoint = (waypointPos * Vector3.new(1, 0, 1) - pos * Vector3.new(1, 0, 1)).Magnitude

			local moveDir = (waypointPos - pos).Unit
			self.navigator.humanoid:Move(moveDir)

			if
				currentWaypoint.Action == Enum.PathWaypointAction.Jump
				and self.navigator.config.AutoJump
			then
				self.navigator.humanoid.Jump = true
			end

			local hasLOS: boolean, result: RaycastResult =
				self.navigator:HasLineOfSight(pos, targetPos)

			if hasLOS then
				self.navigator.stateMachine:ChangeState("Direct")
				return
			end

			if distToWaypoint < (self.navigator.humanoid.WalkSpeed / 16) then
				self.navigator.waypoint += 1
				if self.navigator.waypoint > #self.navigator.waypoints then
					self.navigator.stateMachine:ChangeState("Direct")
					return
				end
			end
		end,

		Exit = function(self: NavigatorState)
			if self.navigator.path then
				self.navigator.path = nil
				table.clear(self.navigator.waypoints)
				self.navigator.waypoint = 0
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
}

export type NavigationController = NavigationControllerProperties & NavigationControllerMethods

type MovementCallback = (
	controller: NavigationController,
	baseDirection: Vector3,
	dt: number,
	distance: number
) -> Vector3?

local NavigationController = {}
NavigationController.__index = NavigationController

function NavigationController.Jump(self: NavigationController)
	self.humanoid.Jump = true
end

function NavigationController.MoveInDirection(self: NavigationController, direction: Vector3)
	if not direction or direction.Magnitude < LOWEST_MAGNITUDE then
		self.humanoid:Move(Vector3.zero)
		return
	end

	self.humanoid:Move(direction)
end

function NavigationController.HasLineOfSight(
	self: NavigationController,
	from: Vector3,
	to: Vector3
): boolean
	local direction = to - from
	local distance = direction.Magnitude

	local result = workspace:Raycast(from, direction.Unit * distance, self.rayParams)

	if not result then return true end

	if result.Instance and self.target then
		if result.Instance == self.target then return true end

		local targetModel = self.target:FindFirstAncestorOfClass("Model")
		if targetModel and result.Instance:IsDescendantOf(targetModel) then return true end
	end

	return false, result
end

function NavigationController.UpdatePathfinding(
	self: NavigationController,
	from: Vector3,
	to: Vector3,
	deltaTime: number
)
	local timeSinceLastCalc = tick() - self.lastCalcPathTime
	if timeSinceLastCalc < self.config.PathRecalculateInterval then return end
	if self.isComputingPath then return end

	local pathFinished = self.path and self.waypoint and self.waypoint > #self.waypoints
	local targetMoved = self.lastTargetPos
		and (to - self.lastTargetPos).Magnitude > self.config.PathRecalculateDistance

	if self.path and not pathFinished and not targetMoved then return end

	self.isComputingPath = true
	self.lastCalcPathTime = tick()

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

			if self.config.Debug then VisualizePath(path) end
		else
			self.path = nil
			table.clear(self.waypoints)
			self.waypoint = 0

			if self.config.Debug then print("No path, dropping") end
		end
	end)
end

function NavigationController:GetBaseDirection(from: Vector3, to: Vector3): Vector3
	local direction = (to - from) * Vector3.new(1, 0, 1)

	if direction.Magnitude < LOWEST_MAGNITUDE then return self.rootPart.CFrame.LookVector end

	return direction.Unit
end

function NavigationController.SetTarget(self: NavigationController, target: BasePart)
	if self.target == target then return end

	self.target = target
	self.lastTargetPos = target.Position

	self.stateMachine:ChangeState("Idle")
end

function NavigationController.ClearTarget(self: NavigationController)
	self.stateMachine:ChangeState("None")

	self.target = nil
	self.humanoid:Move(Vector3.zero)
	self.alignOrient.Enabled = false

	if self.config.Debug then print("Target cleared") end
end

function NavigationController.SetMovementStyle(self: NavigationController, style: MovementStyle)
	if self.config.Debug then print(`Movestyle changed to {style} from {self.config.Style}`) end

	self.config.Style = style
end

function NavigationController.Destroy(self: NavigationController)
	self:ClearTarget()

	self.alignOrient:Destroy()
	self.rotateAttach:Destroy()
	self.stateMachine:Destroy()

	if self.config.Debug then print("Navigator controller destroyed") end
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
				if not config[i] then config[i] = v end
			end
		end

		local root = rig.PrimaryPart or rig:FindFirstChild("HumanoidRootPart")
		if not root then
			error(
				"NavigationController rig must have a PrimaryPart or a part named HumanoidRootPart"
			)
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

		local rayParams = config.RayParams

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

		if config.Debug then print("Navigator controller created successfully") end

		local navigator = setmetatable(
			{
				config = config or table.clone(DEFAULT_CONFIG),
				stateMachine = StateMachine.new({
					CreateNoneState = true,
				}),

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

				isComputingPath = false,
			} :: NavigationController,
			NavigationController
		) :: NavigationController

		for name, state in States do
			local copy = table.clone(state)
			copy["navigator"] = navigator
			navigator.stateMachine:AddState(name, copy)
		end

		if config.Debug then
			navigator.stateMachine:OnStateChanged(function(new, old)
				print("State changed from", old, "to", new)
			end)
		end

		return navigator
	end,

	MovementStyles = MovementStyles,
	StateMachine = StateMachine,
}
