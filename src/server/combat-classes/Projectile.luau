--!native
--!optimize 2

--[=[
	Projectile — server-authoritative moving combat primitive.

	Covers what the ad-hoc `BodyVelocity` + `Heartbeat` raycast blocks in skills
	used to reimplement (Dual Pistols bullets, Gerson's Shell Launch):

	- a travelling visual model
	- a hitbox query via `CombatService:Hitbox`
	- a custom per-frame move function (homing, arcs, acceleration)
	- surface reflection / bouncing
	- piercing, with a unique-target set so nobody is hit twice

	The class reports hits through signals and never applies damage itself.
	Connect `Hit` and call `CombatService:Attack` from the skill.

	```lua
	local Projectile = require(ServerScriptService.server["combat-classes"].Projectile)

	local bullet = Projectile.new({
		Caster = character,
		Skill = self,
		Model = Models["Bullet"],
		Position = origin,
		Direction = RootPart.CFrame.LookVector,
		Speed = 120,
		HitboxSize = 3,
		Lifetime = 2,
		CanPierce = false,
		Reflection = { Enabled = true, Restitution = 0.6 },
	})

	-- Tracked by the skill, so interrupt/respawn cleans it up for free.
	self.Cleaner:Add(bullet)

	bullet.Hit:Connect(function(target)
		CombatService:Attack({ Attacker = character, Victim = target, Info = AttackInfo })
		bullet:Destroy()
	end)

	bullet:Start()
	```

	@class Projectile
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Signal = Crane.Signal
local types = require(ServerScriptService.server.types)

local Projectile = {}
Projectile.__index = Projectile

local DEFAULT_LIFETIME = 5
local DEFAULT_SURFACE_OFFSET = 0.05

-- Characters are resolved by the hitbox query, not the surface sweep. Unless a
-- skill explicitly asks for character bounces, the sweep passes straight through
-- them instead of deflecting off a ragdolling torso.
local function IsCharacterPart(instance: Instance): boolean
	local model = instance:FindFirstAncestorOfClass("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

-- Orients a visual so its -Z axis points along travel. Falls back to a plain
-- position when there is no meaningful direction yet.
local function Orient(position: Vector3, direction: Vector3): CFrame
	if direction.Magnitude < 0.001 then return CFrame.new(position) end
	return CFrame.lookAt(position, position + direction)
end

function Projectile.new(Config: types.ProjectileConfig): types.Projectile
	local Direction = Config.Direction
	if Direction.Magnitude < 0.001 then Direction = Vector3.zAxis end

	local Cleaner = Crane.Buttler.new()

	-- Reflection is opt-in. Without it a projectile flies straight and ends with
	-- reason "Wall" on the first surface it touches.
	local Reflection = {
		Enabled = Config.Reflection ~= nil and Config.Reflection.Enabled == true,
		Restitution = (Config.Reflection and Config.Reflection.Restitution) or 1,
		MaxBounces = (Config.Reflection and Config.Reflection.MaxBounces) or -1,
		IgnoreCharacters = not (Config.Reflection and Config.Reflection.IgnoreCharacters == false),
		SurfaceOffset = (Config.Reflection and Config.Reflection.SurfaceOffset)
			or DEFAULT_SURFACE_OFFSET,
	} :: types.ProjectileReflection

	local self = setmetatable({
		Config = Config,

		Position = Config.Position,
		Velocity = Direction.Unit * Config.Speed,
		Direction = Direction.Unit,
		Speed = Config.Speed,

		Elapsed = 0,
		Traveled = 0,
		HitCount = 0,
		AlreadyHit = {}, --[[ types.Character ]]

		Reflection = Reflection,
		Bounces = 0,

		Running = false,
		Finished = false,

		Cleaner = Cleaner,

		Hit = Signal(),
		Reflect = Signal(),
		End = Signal(),
		Stepped = Signal(),
	}, Projectile) :: types.Projectile

	self.Instance = Cleaner:Clone(Config.Model) :: Model | BasePart

	-- Parent to `workspace.Effects`, never `workspace.Live`. The default hitbox
	-- query whitelists `workspace.Live` only, so the projectile is structurally
	-- unable to detect itself. The workspace root is an equally safe fallback,
	-- since it is not inside `workspace.Live` either.
	self.Instance.Parent = Workspace.Effects or Workspace
	self.Instance:PivotTo(Orient(Config.Position, self.Direction))

	-- Surface sweep params are the inverse of the hitbox params: geometry lives
	-- outside `workspace.Live`, so exclude the characters and keep the world.
	local RayParams = RaycastParams.new()
	RayParams.FilterType = Enum.RaycastFilterType.Exclude
	RayParams.RespectCanCollide = true
	RayParams:AddToFilter(Workspace.Live)
	RayParams:AddToFilter(self.Instance)

	self.RayParams = RayParams

	return self
end

--[=[
	Single termination path. Disconnects the step loop, releases the model and
	fires `End`. Idempotent, so a skill may call `Destroy` inside a `Hit`
	callback without racing the projectile's own limits.
]=]
function Projectile.Finish(self: types.Projectile, reason: string)
	if self.Finished then return end
	self.Finished = true
	self.Running = false

	if self.Connection then
		self.Cleaner:Remove(self.Connection)
		self.Connection = nil
	end

	self.Cleaner:Destroy()

	self.End:Fire(reason)
end

--[=[
	Marks the projectile as running and subscribes the step loop to Heartbeat.
	Safe to call twice; the second call is a no-op.
]=]
function Projectile.Start(self: types.Projectile)
	if self.Running or self.Finished then return end
	self.Running = true

	self.Connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		Projectile.Step(self, deltaTime)
	end)

	self.Cleaner:Add(self.Connection)
end

--[=[
	Stops the step loop and releases the model. Fires `End` with `"Stopped"`
	unless another reason is given.
]=]
function Projectile.Stop(self: types.Projectile, reason: string?)
	Projectile.Finish(self, reason or "Stopped")
end

--[=[
	Full teardown. Called automatically when the owning skill's `Cleaner` cleans
	up, which covers interrupt, spec removal and respawn.
]=]
function Projectile.Destroy(self: types.Projectile)
	Projectile.Finish(self, "Destroyed")

	self.Hit:DisconnectAll()
	self.Reflect:DisconnectAll()
	self.End:DisconnectAll()
	self.Stepped:DisconnectAll()
end

function Projectile.SetVelocity(self: types.Projectile, velocity: Vector3)
	self.Velocity = velocity
	self.Speed = velocity.Magnitude

	if self.Speed < 0.001 then
		self.Direction = Vector3.zAxis
		return
	end

	self.Direction = velocity / self.Speed
end

function Projectile.SetDirection(self: types.Projectile, direction: Vector3, speed: number?)
	if direction.Magnitude < 0.001 then return end

	self.Speed = speed or self.Speed
	self.Direction = direction.Unit
	self.Velocity = self.Direction * self.Speed
end

--[=[
	Bounces off a surface normal, keeping the current speed scaled by
	`Restitution`. Consumes one bounce from the budget.

	Used by the swept surface test, and callable directly from a skill.
]=]
function Projectile.Reflect(self: types.Projectile, normal: Vector3)
	local reflected = self.Direction - (2 * self.Direction:Dot(normal) * normal)
	if reflected.Magnitude < 0.001 then return end

	self.Bounces += 1
	self:SetDirection(reflected, self.Speed * self.Reflection.Restitution)

	self.Reflect:Fire(nil, self.Direction)
end

--[=[
	Resolves a hit against a target, honouring the unique-target set.

	Returns `true` when the target was newly hit, `false` when this projectile had
	already hit them.

	@param position World position of the hit, forwarded to the `Hit` signal.
]=]
function Projectile.HitTarget(
	self: types.Projectile,
	target: types.Character,
	position: Vector3
): boolean
	if self.AlreadyHit[target] then return false end

	self.AlreadyHit[target] = true
	self.HitCount += 1

	self.Hit:Fire(target, position)

	return true
end

--[=[
	Advances the projectile by one frame:

	1. resolves velocity (custom move function wins over gravity)
	2. sweeps a ray across the whole step so fast projectiles cannot tunnel
	3. reflects off, or stops at, whatever the sweep hit
	4. queries the hitbox and resolves targets against the unique-target set
	5. checks the self-imposed lifetime / distance limits
]=]
function Projectile.Step(self: types.Projectile, deltaTime: number)
	local Config = self.Config
	local Reflection = self.Reflection

	self.Elapsed += deltaTime

	-- 1. Motion. A custom move function wins; otherwise gravity accumulates.
	local velocity = self.Velocity + (Config.Gravity or Vector3.zero) * deltaTime

	if Config.MoveFunction then
		local override = Config.MoveFunction(self, {
			Velocity = velocity,
			Direction = self.Direction,
			Position = self.Position,
			DeltaTime = deltaTime,
			Elapsed = self.Elapsed,
			Traveled = self.Traveled,
		})

		if override then velocity = override end
	end

	self:SetVelocity(velocity)

	local origin = self.Position
	local destination = origin + self.Velocity * deltaTime

	-- 2. Swept raycast across the entire step.
	local result = nil

	if (destination - origin).Magnitude > 0.001 then
		result = Workspace:Raycast(origin, destination - origin, self.RayParams)

		if result and Reflection.IgnoreCharacters and IsCharacterPart(result.Instance) then
			result = nil
		end
	end

	-- 3. Surface response.
	if result then
		if not Reflection.Enabled then
			destination = result.Position
			self.Position = destination
			self.Instance:PivotTo(Orient(destination, self.Direction))
			Projectile.Finish(self, "Wall")
			return
		end

		local reflected = self.Direction - (2 * self.Direction:Dot(result.Normal) * result.Normal)

		if reflected.Magnitude < 0.001 then
			-- Degenerate bounce (perfectly head-on), just stop at the surface.
			self.Position = result.Position
			self.Instance:PivotTo(Orient(self.Position, self.Direction))
			Projectile.Finish(self, "Bounce")
			return
		end

		self.Bounces += 1
		self:SetDirection(reflected, self.Speed * Reflection.Restitution)
		self.Reflect:Fire(result, self.Direction)

		-- Nudge off the normal so the next sweep does not re-hit this surface.
		destination = result.Position + result.Normal * Reflection.SurfaceOffset

		if Reflection.MaxBounces >= 0 and self.Bounces > Reflection.MaxBounces then
			self.Position = destination
			self.Instance:PivotTo(Orient(destination, self.Direction))
			Projectile.Finish(self, "Bounce")
			return
		end
	end

	-- 4. Commit position and orientation.
	self.Position = destination
	self.Traveled += (destination - origin).Magnitude
	self.Instance:PivotTo(Orient(destination, self.Direction))

	-- 5. Hitbox query at the new position.
	local Info = {
		Size = Config.HitboxSize,
		Origin = CFrame.new(destination),
		-- Defaults to ignoring the caster, matching how skills query hitboxes.
		CanQueryCaster = Config.IgnoreCaster == false,
		Debug = Config.Debug,
	}

	if Config.HitboxOffset then Info.Offset = Config.HitboxOffset end

	if not self.CombatService then self.CombatService = Crane:GetService("CombatService") end

	local targets = self.CombatService:Hitbox({
		Caster = Config.Caster,
		Skill = Config.Skill,
		Info = Info,
	})

	for _, target: types.Character in targets do
		if not self:HitTarget(target, destination) then continue end
		if not Config.CanPierce then
			Projectile.Finish(self, "Hit")
			return
		end
	end

	-- 6. Self-imposed limits.
	local Lifetime = Config.Lifetime or DEFAULT_LIFETIME
	local MaxDistance = Config.MaxDistance

	if self.Elapsed >= Lifetime then
		Projectile.Finish(self, "Lifetime")
	elseif MaxDistance and self.Traveled >= MaxDistance then
		Projectile.Finish(self, "Distance")
	else
		self.Stepped:Fire(deltaTime)
	end
end

return Projectile
