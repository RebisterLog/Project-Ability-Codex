--!strict

local ChargeState = require("../src/shared/combat/ChargeState")

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

local function make(state: { [string]: any }): ChargeState.State
	const value: ChargeState.State = {
		Amount = 0,
		LastGainAt = 0,
		Filling = false,
		FillStartedAt = 0,
		FillStartAmount = 0,
		Max = 100,
		FillRate = 20,
		DecayRate = 10,
		HoldSeconds = 5,
	}

	for key, field in state do
		(value :: any)[key] = field
	end

	return value
end

do
	const state = make({ Filling = true, FillStartAmount = 10, FillStartedAt = 100 })
	equal("fill: grows from the start amount", ChargeState.Effective(state, 101.5), 40)
	equal("fill: clamps at max", ChargeState.Effective(state, 110), 100)
	equal("fill: expiry is suppressed", ChargeState.ExpiryAt(state), 0)
end

do
	const state = make({ Amount = 50, LastGainAt = 100 })
	equal("hold: flat until the window ends", ChargeState.Effective(state, 104), 50)
	equal("decay: linear after the hold", ChargeState.Effective(state, 106), 40)
	equal("decay: clamps at zero", ChargeState.Effective(state, 200), 0)
	equal("expiry: amount + hold + decay tail", ChargeState.ExpiryAt(state), 110)
end

do
	const state = make({ Amount = 0, LastGainAt = 100 })
	equal("empty: no expiry", ChargeState.ExpiryAt(state), 0)
end

do
	const state = make({ Amount = 50, LastGainAt = 100, DecayRate = 0 })
	equal("zero decay: no expiry", ChargeState.ExpiryAt(state), 0)
	equal("zero decay: value never drains", ChargeState.Effective(state, 200), 50)
end

do
	const state = make({
		Amount = 50,
		LastGainAt = 100,
		DamageMultiplier = 1.25,
	})
	const result = ChargeState.Snapshot(state)
	equal("snapshot: carries the amount", result.Amount, 50)
	equal("snapshot: carries extras", (result :: any).DamageMultiplier, 1.25)
	equal("snapshot: computes expiry", result.ExpiresAt, 110)
	check("snapshot: does not alias the source", result ~= state)
	equal("snapshot: source unchanged", (state :: any).ExpiresAt or 0, 0)
end

if #failures > 0 then
	for _, failure in failures do
		print(`FAIL {failure}`)
	end
	print(`ChargeState: {passed} passed, {#failures} failed`)
	error("ChargeState tests failed")
end

print(`ChargeState: {passed} passed, 0 failed`)
