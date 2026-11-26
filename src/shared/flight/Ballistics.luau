--!native
--!optimize 2

--[=[ Ballistics.

   A deterministic projectile integrator shared between the client flight
   visual and the server's hitbox trajectory. Both sides must agree to the
   exact numbers, otherwise the rendered projectile opens somewhere the
   hitbox can never touch.

   One frame:
   - gravity is applied to velocity
   - the ray is swept across the whole step so a fast projectile cannot
     tunnel through a wall
   - reflection, restitution and the surface offset are shared with the server
]=]

local FLOOR_Y = 0

local function IsCharacterPart(instance: Instance): boolean
	const model = instance:FindFirstAncestorOfClass("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

local Ballistics = {}

--- Advance one frame. Returns the new position, the new velocity and whether
--- the trajectory touched the floor.
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

	local result = nil
	if reflection and reflection.Params and workspace and workspace.Raycast then
		result = workspace:Raycast(position, delta, reflection.Params)

		if result and reflection.IgnoreCharacters and IsCharacterPart(result.Instance) then
			result = nil
		end
	end

	if result then
		if not reflection.Enabled then return result.Position, Vector3.zero, true end

		const normal = result.Normal
		const incoming = velocity.Unit
		const reflected = incoming - (2 * incoming:Dot(normal) * normal)
		if reflected.Magnitude < 0.001 then return result.Position, Vector3.zero, true end

		velocity = reflected * (velocity.Magnitude * reflection.Restitution)
		return result.Position + normal * (reflection.SurfaceOffset or 0.05), velocity, false
	end

	if destination.Y <= FLOOR_Y then
		return Vector3.new(destination.X, FLOOR_Y, destination.Z), velocity, true
	end

	return destination, velocity, false
end

return Ballistics
