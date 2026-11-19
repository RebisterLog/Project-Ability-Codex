--!strict
--- Tests for the pure `AttackInfo.Knockback` resolver.
---
---   lune run tests/Knockback.luau
---
--- The resolver deliberately has no Roblox globals, so the cases below use plain
--- `{ x, y, z }` tables instead of Vector3/CFrame. What matters here is the
--- contract: presets, direction modes, explicit overrides and the "Auto" force.

local Knockback = require("../src/shared/combat/Knockback")

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

local function vec(name: string, actual: Knockback.Vec3, x: number, y: number, z: number)
	equal(`{name}.x`, actual.x, x)
	equal(`{name}.y`, actual.y, y)
	equal(`{name}.z`, actual.z, z)
end

--- Attacker at the origin looking down +Z, target 10 studs in front of them.
local CONTEXT: Knockback.Context = {
	Attacker = { x = 0, y = 0, z = 0 },
	Target = { x = 0, y = 0, z = 10 },
	AttackerLook = { x = 0, y = 0, z = 1 },
}

-- DEFAULTS -------------------------------------------------------------------

do
	const result = Knockback.Build(nil, CONTEXT)
	vec("defaults: velocity", result.Velocity, 0, 0, 0)
	vec("defaults: maxForce", result.MaxForce, 100000, 0, 100000)
	equal("defaults: hold", result.Hold, 0.1)
	check("defaults: stiffness is math.huge", result.Stiffness == math.huge)
end

-- PRESETS --------------------------------------------------------------------

do
	const result = Knockback.Build({ Preset = "Launch" } :: any, CONTEXT)
	-- Direction defaults to AwayFromAttacker and is normalised, so Push is exact.
	vec("Launch: velocity", result.Velocity, 0, 50, 40)
	vec("Launch: maxForce unlocks Y", result.MaxForce, 100000, 100000, 100000)
	equal("Launch: hold", result.Hold, 0.1)
end

do
	const result =
		Knockback.Build({ Preset = "Tap", Direction = { Mode = "Shove" } } :: any, CONTEXT)
	check(
		"unknown Direction.Mode falls back to Custom/zero",
		result.Velocity.x == 0 and result.Velocity.z == 0
	)
end

-- DIRECTION MODES ------------------------------------------------------------

do
	const result = Knockback.Build(
		{
			Preset = "Shove",
			Direction = { Mode = "TowardsAttacker" },
		} :: any,
		CONTEXT
	)
	vec("TowardsAttacker reverses", result.Velocity, 0, 0, -40)
end

do
	const result = Knockback.Build(
		{
			Push = 20,
			Direction = { Mode = "FromPoint", Point = { Position = { x = 0, y = 0, z = 0 } } },
		} :: any,
		CONTEXT
	)
	vec("FromPoint", result.Velocity, 0, 0, 20)
end

do
	const result = Knockback.Build(
		{
			Push = 30,
			Direction = { Mode = "Custom", Vector = { x = 0, y = 0, z = 5 } },
		} :: any,
		CONTEXT
	)
	vec("Custom is normalised", result.Velocity, 0, 0, 30)
end

do
	const result = Knockback.Build(
		{
			Push = 30,
			Direction = { Mode = "Custom", Vector = { x = 0, y = 0, z = 0 } },
		} :: any,
		CONTEXT
	)
	vec("zero-length direction stays finite", result.Velocity, 0, 0, 0)
end

-- ADDITIVE DIRECTIONS --------------------------------------------------------

do
	const result = Knockback.Build(
		{
			Push = 10,
			Direction = {
				Mode = "AwayFromAttacker",
				Add = { { Mode = "Custom", Vector = { x = 2, y = 0, z = 0 } } },
			},
		} :: any,
		CONTEXT
	)
	-- Add is raw: 1 unit of basis * 10 plus 2 on X.
	vec("Add.Custom", result.Velocity, 2, 0, 10)
end

do
	const result = Knockback.Build(
		{
			Push = 0,
			Direction = {
				Mode = "AwayFromAttacker",
				Add = { { Mode = "ToFront", Distance = 5 } },
			},
		} :: any,
		CONTEXT
	)
	-- AttackerLook*5 lands 5 studs in front of the attacker, target is at 10.
	vec("Add.ToFront", result.Velocity, 0, 0, -5)
end

-- OVERRIDES ------------------------------------------------------------------

do
	const result = Knockback.Build(
		{
			Preset = "Launch",
			Push = 7,
			Lift = 3,
			Hold = 0.4,
			Stiffness = 500,
			MaxForce = { x = 1, y = 2, z = 3 },
		} :: any,
		CONTEXT
	)
	vec("explicit fields beat preset", result.Velocity, 0, 3, 7)
	vec("explicit MaxForce", result.MaxForce, 1, 2, 3)
	equal("explicit Hold", result.Hold, 0.4)
	equal("explicit Stiffness", result.Stiffness, 500)
end

do
	const result = Knockback.Build({ Preset = "Shove" } :: any, {
		Attacker = nil,
		Target = { x = 0, y = 0, z = 10 },
		AttackerLook = nil,
	})
	vec("missing attacker is safe", result.Velocity, 0, 0, 0)
end

print(`Knockback: {passed} passed, {#failures} failed`)
if #failures > 0 then
	for _, failure in failures do
		warn(failure)
	end
	error("Knockback tests failed")
end
