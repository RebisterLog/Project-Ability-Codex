--!strict
--- Tests for the pure `DashMovement.ResolveMotion` resolver.
---
---   lune run tests/DashMovement.luau
---
--- The resolver has no Roblox globals, so the cases below use plain scalars.
--- What matters is the contract behind the new dash: one flat velocity and one
--- Y force budget for the whole dash, then a fixed lower speed for the exit
--- phase — same value on ground and in the air, with no acceleration.

local DashMovement = require("../src/shared/DashMovement")

local passed = 0
local failures: { string } = {}

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		return
	end

	table.insert(failures, if detail ~= nil then `{name}: {detail}` else name)
end

local function equal(name: string, actual: number, expected: number)
	check(name, math.abs(actual - expected) < 1e-6, `expected {expected}, got {actual}`)
end

local function motion(directionX: number, directionZ: number, speed: number, force: number)
	return DashMovement.ResolveMotion(directionX, directionZ, speed, force)
end

-- CONSTANT HORIZONTAL VELOCITY ------------------------------------------------

do
	const result = motion(0, -1, 100, 100_000)
	equal("forward X", result.Velocity.x, 0)
	equal("forward Z", result.Velocity.z, -100)
	equal("Y target stays at zero", result.Velocity.y, 0)
	equal("X force budget", result.Force.x, 100_000)
	equal("Y force budget stays on", result.Force.y, 100_000)
	equal("Z force budget", result.Force.z, 100_000)
end

do
	-- A diagonal input is still flattened and scaled by the same speed; no
	-- component is ever added to Y.
	const inv = 1 / math.sqrt(2)
	const result = motion(inv, -inv, 100, 90_000)
	equal("diagonal X", result.Velocity.x, 100 * inv)
	equal("diagonal Z", result.Velocity.z, -100 * inv)
	equal("diagonal Y", result.Velocity.y, 0)
end

-- CONSTANT DIRECTION -----------------------------------------------------------

do
	-- The resolver has no elapsed-time argument: for a given speed it always
	-- yields the same flat vector. The tail curve lives in ResolveSpeed.
	const start = motion(0, -1, DashMovement.Config.Speed, DashMovement.Config.Force)
	const again = motion(0, -1, DashMovement.Config.Speed, DashMovement.Config.Force)
	equal("same input gives same velocity", start.Velocity.z, again.Velocity.z)
	equal("speed is the configured speed", -again.Velocity.z, DashMovement.Config.Speed)
end

-- BRAKE CURVE ------------------------------------------------------------------

do
	-- move 0.2s, brake over the last 0.1s: flat to 0.1, then ease-out to 32.
	const speed = DashMovement.ResolveSpeed(0, 0.2, 0.1, 100, 32)
	const beforeBrake = DashMovement.ResolveSpeed(0.09, 0.2, 0.1, 100, 32)
	const atStart = DashMovement.ResolveSpeed(0.1, 0.2, 0.1, 100, 32)
	const midpoint = DashMovement.ResolveSpeed(0.15, 0.2, 0.1, 100, 32)
	const atEnd = DashMovement.ResolveSpeed(0.2, 0.2, 0.1, 100, 32)
	const after = DashMovement.ResolveSpeed(0.5, 0.2, 0.1, 100, 32)

	equal("curve starts at dash speed", speed, 100)
	equal("flat before the brake window", beforeBrake, 100)
	equal("brake boundary equals dash speed", atStart, 100)
	equal("ease-out midpoint drops fast", midpoint, 49)
	equal("brake ends at exit speed", atEnd, 32)
	equal("clamped after the dash", after, 32)
	check(
		"monotonic drop",
		speed >= beforeBrake
			and beforeBrake >= atStart
			and atStart >= midpoint
			and midpoint >= atEnd
	)
end

-- EXIT PHASE ------------------------------------------------------------------

do
	-- The exit retargets the very same resolver to a fixed, lower speed along
	-- the original direction; that value is what the character keeps.
	const exitSpeed = DashMovement.Config.ExitSpeed
	const result = motion(0, -1, exitSpeed, DashMovement.Config.Force)
	check("exit speed is non-zero", exitSpeed > 0)
	check("exit speed is below dash speed", exitSpeed < DashMovement.Config.Speed)
	equal("exit: X velocity", result.Velocity.x, 0)
	equal("exit: Y velocity stays zero", result.Velocity.y, 0)
	equal("exit: Z velocity", result.Velocity.z, -exitSpeed)
	equal("exit: Y force budget stays on", result.Force.y, DashMovement.Config.Force)
end

-- CONFIG SHAPE ----------------------------------------------------------------

do
	check("dash speed is positive", DashMovement.Config.Speed > 0)
	check("force budget is positive", DashMovement.Config.Force > 0)
	check(
		"brake fits inside the dash",
		DashMovement.Config.BrakeFrames < DashMovement.Config.MoveFrames
	)
	check("brake window is positive", DashMovement.Config.BrakeFrames > 0)
	check("exit phase is present", DashMovement.Config.ExitFrames > 0)
	equal("frames to seconds", DashMovement.FramesToSeconds(6), 0.1)
end

print(`DashMovement: {passed} passed, {#failures} failed`)
if #failures > 0 then
	for _, failure in failures do
		warn(failure)
	end
	error("DashMovement tests failed")
end
