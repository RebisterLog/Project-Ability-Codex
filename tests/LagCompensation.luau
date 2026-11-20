--!strict
--- Tests for the pure lag-compensation contract.
---
---   lune run tests/LagCompensation.luau
---
--- No Roblox globals are used, so the same module can be checked headlessly
--- and required by both the client and the server at runtime.

local LagCompensation = require("../src/shared/combat/LagCompensation")

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

do
	const now = 100

	equal(
		"clamp: valid time passes through",
		LagCompensation.ClampAimTime(now, 99.8, 0.35) :: number,
		99.8
	)
	equal(
		"clamp: future time is pulled back",
		LagCompensation.ClampAimTime(now, 100.2, 0.35) :: number,
		100
	)
	equal(
		"clamp: ancient time is bounded by the window",
		LagCompensation.ClampAimTime(now, 50, 0.35) :: number,
		99.65
	)

	check("clamp: nil is rejected", LagCompensation.ClampAimTime(now, nil, 0.35) == nil)
	check("clamp: zero is rejected", LagCompensation.ClampAimTime(now, 0, 0.35) == nil)
	check("clamp: NaN is rejected", LagCompensation.ClampAimTime(now, 0 / 0, 0.35) == nil)
	check(
		"clamp: negative window falls back to default",
		LagCompensation.ClampAimTime(now, 99, -1) ~= nil
	)
end

do
	const now = 100
	const fresh = { Normal = 99.8, Half = 99.6, ReceivedAt = 99.95 }

	equal(
		"choose: normal clock",
		LagCompensation.ChooseTime(fresh, false, now, 0.35) :: number,
		99.8
	)
	equal("choose: half clock", LagCompensation.ChooseTime(fresh, true, now, 0.5) :: number, 99.6)
	check("choose: missing sample", LagCompensation.ChooseTime(nil, false, now, 0.35) == nil)

	const stale = { Normal = 90, Half = 90, ReceivedAt = 99 }
	check(
		"choose: stale sample is discarded",
		LagCompensation.ChooseTime(stale, false, now, 0.35) == nil
	)

	const uninitialized = { Normal = 0, Half = 0, ReceivedAt = 99.99 }
	check(
		"choose: uninitialized clock is discarded",
		LagCompensation.ChooseTime(uninitialized, false, now, 0.35) == nil
	)
end

do
	equal("inflation: default", LagCompensation.BroadphaseInflation(), 0.35 * 32)
	equal("inflation: custom window", LagCompensation.BroadphaseInflation(0.1, 20), 2)
	equal(
		"inflation: invalid window falls back",
		LagCompensation.BroadphaseInflation(-1, 20),
		0.35 * 20
	)
end

do
	-- Box half extents 2 x 3 x 1; sphere radius 0.5.
	check("box: center inside", LagCompensation.LocalSphereOverlapsBox(0, 0, 0, 0.5, 2, 3, 1))
	check("box: face contact", LagCompensation.LocalSphereOverlapsBox(2.4, 0, 0, 0.5, 2, 3, 1))
	check(
		"box: corner contact",
		LagCompensation.LocalSphereOverlapsBox(2.3, 2.9, 0.8, 0.5, 2, 3, 1)
	)
	check("box: clear miss", not LagCompensation.LocalSphereOverlapsBox(5, 0, 0, 0.5, 2, 3, 1))
	check(
		"box: tangent outside",
		not LagCompensation.LocalSphereOverlapsBox(2.51, 0, 0, 0.5, 2, 3, 1)
	)
end

do
	check("sphere: overlapping", LagCompensation.SphereOverlapsSphere(3, 2, 1.1))
	check("sphere: disjoint", not LagCompensation.SphereOverlapsSphere(3.2, 2, 1))
	check("sphere: exact tangent", LagCompensation.SphereOverlapsSphere(3, 2, 1))
end

if #failures > 0 then
	for _, failure in failures do
		print(`FAIL {failure}`)
	end
	error(`LagCompensation: {#failures} failure(s)`)
end

print(`LagCompensation: {passed} checks passed`)
