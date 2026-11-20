--!strict
--- Tests for the pure `DashMovement.ResolveMotion` resolver.
---
---   lune run tests/DashMovement.luau
---
--- The resolver has no Roblox globals, so the cases below use plain scalars.
--- What matters is the contract that gives the air dash its flat trajectory:
--- only an active air dash gets a Y force budget, and releasing that budget
--- is what hands the character back to gravity at the end of the dash.

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

local function motion(name: string, hovering: boolean, verticalSpeed: number)
	return DashMovement.ResolveMotion(0, -1, 100, 90_000, hovering, verticalSpeed)
end

-- GROUND ---------------------------------------------------------------------

do
	const result = motion("ground", false, 0)
	equal("ground: forward X", result.Velocity.x, 0)
	equal("ground: forward Z", result.Velocity.z, -100)
	equal("ground: Y target stays at zero", result.Velocity.y, 0)
	equal("ground: no Y force budget", result.Force.y, 0)
	equal("ground: X force budget", result.Force.x, 90_000)
	equal("ground: Z force budget", result.Force.z, 90_000)
end

-- AIR HOVER ------------------------------------------------------------------

do
	const result = motion("air", true, DashMovement.Config.AirVerticalSpeed)
	equal("air: horizontal speed is unchanged", result.Velocity.z, -100)
	equal(
		"air: Y target is the hover speed",
		result.Velocity.y,
		DashMovement.Config.AirVerticalSpeed
	)
	equal("air: Y gets the force budget", result.Force.y, 90_000)
	equal("air: X force budget", result.Force.x, 90_000)
	check(
		"air: hover speed is zero (strictly horizontal)",
		DashMovement.Config.AirVerticalSpeed == 0
	)
end

do
	-- The config is tunable: a non-zero hover speed must be respected.
	const result = DashMovement.ResolveMotion(1, 0, 40, 50_000, true, 12)
	equal("tunable lift: Y target", result.Velocity.y, 12)
	equal("tunable lift: Y force budget", result.Force.y, 50_000)
end

-- BRAKING KEEPS THE HOVER ----------------------------------------------------

do
	-- Near the air cap speedFactor drops, but the vertical component must not.
	const result = DashMovement.ResolveMotion(0, -1, 100 * 0.45, 90_000, true, 0)
	equal("braking: reduced horizontal speed", result.Velocity.z, -45)
	equal("braking: Y target still zero", result.Velocity.y, 0)
	equal("braking: Y force still available", result.Force.y, 90_000)
end

-- END OF DASH RELEASES GRAVITY ----------------------------------------------

do
	const result = DashMovement.ResolveMotion(0, -1, 45, 90_000, false, 0)
	equal("tail: residual horizontal speed", result.Velocity.z, -45)
	equal("tail: Y force released", result.Force.y, 0)
	equal("tail: horizontal force kept", result.Force.x, 90_000)
end

-- CONFIG SHAPE ---------------------------------------------------------------

do
	check("air mode is enabled", DashMovement.Config.AirHover)
	check(
		"air dash outlasts the ground dash",
		DashMovement.Config.AirMoveFrames > DashMovement.Config.MoveFrames
	)
	equal("frames to seconds", DashMovement.FramesToSeconds(18), 0.3)
end

print(`DashMovement: {passed} passed, {#failures} failed`)
if #failures > 0 then
	for _, failure in failures do
		warn(failure)
	end
	error("DashMovement tests failed")
end
