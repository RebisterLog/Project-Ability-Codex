--!native
--!optimize 2

--[=[ Ballistics.

   A deterministic projectile integrator shared between the client flight
   simulation and the server's landing detection. Both sides must agree to
   the exact numbers, otherwise the puddle opens somewhere the can never
   visually touches.

   One frame:
   - gravity is applied to velocity
   - the ray is swept across the whole step so a fast projectile cannot
     tunnel through a wall
   - gravity and the sweep must agree with the caller's reflection config, so
     the result is identical between client and server
   - the y coordinate clamps to the infinite floor `y = 0`
   - the `grounded` flag is set when the trajectory touches the floor
]=]

const FLOOR_Y = 0

-- Characters are resolved by the caller; mirror Projectile's tendency to let
-- the sweep pass through them so they don't read as floor/walls.
const function IsCharacterPart(instance: Instance): boolean
	const model = instance:FindFirstAncestorOfClass("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

const Ballistics = {}

--- Advance one frame.
--- `reflection` is optional; when given, a raycast is swept across the move
--- and the result drives the wall/floor response. Returns the new position,
--- the new velocity and whether the object is at rest on the floor.
function Ballistics.step(
	position: Vector3,
	velocity: Vector3,
	gravity: Vector3,
	deltaTime: number,
	reflection: {
		Params: any?,
		Enabled: boolean,
		Restitution: number,
		IgnoreCharacters: boolean,
		SurfaceOffset: number,
	}?
): (Vector3, Vector3, boolean)
	velocity = velocity + gravity * deltaTime

	const delta = velocity * deltaTime
	const destination = position + delta

	-- A caller that owns the sweep should provide `reflection.IgnoreCharacters`
	-- and do the cast itself; here the module does it always.
	local result = nil
	if reflection and reflection.Params and workspace and workspace.Raycast then
		result = workspace:Raycast(position, delta, reflection.Params)

		if result and reflection.IgnoreCharacters and IsCharacterPart(result.Instance) then
			result = nil
		end
	end

	if result then
		if not reflection.Enabled then
			position = result.Position
			return position, Vector3.zero, true
		end

		const normal = result.Normal
		const incoming = velocity.Unit

		const reflected = incoming - (2 * incoming:Dot(normal) * normal)
		if reflected.Magnitude < 0.001 then
			position = result.Position
			return position, Vector3.zero, true
		end

		const reflectedVelocity = reflected * (velocity.Magnitude * reflection.Restitution)
		velocity = reflectedVelocity
		position = result.Position + normal * (reflection.SurfaceOffset or 0.05)
		return position, velocity, false
	end

	position = destination

	if position.Y <= FLOOR_Y then
		position = Vector3.new(position.X, FLOOR_Y, position.Z)
		return position, velocity, true
	end

	return position, velocity, false
end

return Ballistics
