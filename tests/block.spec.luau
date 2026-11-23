--!strict

--- Табличные тесты `AttackInfo.Block`: каждый флаг проверяется и по отдельности,
--- и в сочетаниях. Запускается через `lune run tools/run-tests.luau`.
local Block = require("../src/shared/combat/Block")

type Case = {
	name: string,
	config: Block.Config?,
	victim: Block.VictimState,
	expect: { [string]: boolean },
}

const BLOCKING = { Blocking = true, PerfectBlocking = false } :: Block.VictimState
const PERFECT = { Blocking = true, PerfectBlocking = true } :: Block.VictimState
const NO_BLOCK = { Blocking = false, PerfectBlocking = false } :: Block.VictimState

const function config(
	blockable: boolean,
	perfect: boolean,
	breakBlock: boolean,
	cancel: boolean,
	ignore: boolean
): Block.Config
	return {
		Blockable = blockable,
		PerfectBlockable = perfect,
		BlockBreak = breakBlock,
		BlockCancel = cancel,
		BlockIgnore = ignore,
	}
end

local cases: { Case } = {
	{
		name = "views: no config means nothing is blockable",
		config = nil,
		victim = BLOCKING,
		expect = {
			Blocked = false,
			PerfectBlocked = false,
			BlockBroken = false,
			BlockCanceled = false,
			BlockIgnored = false,
			Absorbed = false,
		},
	},
	{
		name = "no block held: no block states",
		config = config(true, true, true, true, false),
		victim = NO_BLOCK,
		expect = {
			Blocked = false,
			PerfectBlocked = false,
			BlockBroken = false,
			BlockCanceled = false,
			BlockIgnored = false,
			Absorbed = false,
		},
	},
	{
		name = "ordinary block absorbs the hit",
		config = config(true, false, false, false, false),
		victim = BLOCKING,
		expect = {
			Blocked = true,
			PerfectBlocked = false,
			BlockBroken = false,
			BlockCanceled = false,
			BlockIgnored = false,
			Absorbed = true,
		},
	},
	{
		name = "block break with blockable: absorbed, guard broken",
		config = config(true, false, true, false, false),
		victim = BLOCKING,
		expect = {
			Blocked = true,
			PerfectBlocked = false,
			BlockBroken = true,
			BlockCanceled = false,
			BlockIgnored = false,
			Absorbed = true,
		},
	},
	{
		name = "block break without blockable: full damage still breaks the guard",
		config = config(false, false, true, false, false),
		victim = BLOCKING,
		expect = {
			Blocked = false,
			PerfectBlocked = false,
			BlockBroken = true,
			BlockCanceled = false,
			BlockIgnored = false,
			Absorbed = false,
		},
	},
	{
		name = "ignore dominates: other flags produce no states",
		config = config(true, true, true, true, true),
		victim = BLOCKING,
		expect = {
			Blocked = false,
			PerfectBlocked = false,
			BlockBroken = false,
			BlockCanceled = false,
			BlockIgnored = true,
			Absorbed = false,
		},
	},
	{
		name = "cancel alone passes damage",
		config = config(false, false, false, true, false),
		victim = BLOCKING,
		expect = {
			Blocked = false,
			PerfectBlocked = false,
			BlockBroken = false,
			BlockCanceled = true,
			BlockIgnored = false,
			Absorbed = false,
		},
	},
	{
		name = "cancel and blockable coexist: both states are set",
		config = config(true, false, false, true, false),
		victim = BLOCKING,
		expect = {
			Blocked = true,
			PerfectBlocked = false,
			BlockBroken = false,
			BlockCanceled = true,
			BlockIgnored = false,
			Absorbed = true,
		},
	},
	{
		name = "perfect block parries; block break does not fire",
		config = config(true, true, true, false, false),
		victim = PERFECT,
		expect = {
			Blocked = false,
			PerfectBlocked = true,
			BlockBroken = false,
			BlockCanceled = false,
			BlockIgnored = false,
			Absorbed = true,
		},
	},
	{
		name = "perfect timing without perfect blockable falls back to normal block",
		config = config(true, false, true, false, false),
		victim = PERFECT,
		expect = {
			Blocked = true,
			PerfectBlocked = false,
			BlockBroken = true,
			BlockCanceled = false,
			BlockIgnored = false,
			Absorbed = true,
		},
	},
}

local failed = 0
local checked = 0

for _, case in cases do
	const result: any = Block.Resolve(case.config, case.victim)
	for key, expected in case.expect do
		checked += 1
		if result[key] ~= expected then
			failed += 1
			print(`FAIL {case.name}: {key} expected {expected}, got {result[key]}`)
		end
	end
end

if failed > 0 then error(`block resolver: {failed}/{checked} assertions failed`) end

print(`OK: block resolver ({#cases} cases, {checked} assertions)`)
