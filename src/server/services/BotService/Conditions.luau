--!native
--!optimize 2

--- Target conditions as a bitmask.
---
--- The module is deliberately self-contained: no `game`, no `ReplicatedStorage`.
--- That lets the very same file load in Roblox and in `lune` (the scorer tests
--- inline this file instead of `require`), at the cost of duplicating the
--- condition vocabulary from `shared/bot-characters.luau`. Divergence between
--- the two vocabularies is caught by `tools/tests/bot-skill-priority.luau`,
--- which compares them in both directions.
---
--- Why a mask and not a list of strings: conditions are evaluated every tick for
--- every skill, and `table.find` over an array of strings costs
--- O(conditions × skills) string comparisons. A bitwise AND is one operation and
--- allocates nothing.

-- Order is fixed: it assigns the bit numbers. Condition lists coming from configs
-- are converted once and cached, so the order only matters for keeping masks
-- stable across server restarts.
const ORDER = {
	"TARGET_SHORT_RANGE",
	"TARGET_MIDDLE_RANGE",
	"TARGET_LARGE_RANGE",

	"TARGET_ARMORED",
	"TARGET_ATTACKING",
	"TARGET_STUNNED",
	"TARGET_RAGDOLLED",
	"TARGET_DODGING",
	"TARGET_INTERRUPTABLE",

	"TARGET_BLOCKING",
	"TARGET_PERFECT_BLOCKING",
	"TARGET_BLOCKABLE",
	"TARGET_PERFECT_BLOCKABLE",
	"TARGET_IGNORE_BLOCK",
	"TARGET_BLOCK_BREAKING",
}

const BITS: { [string]: number } = {}

for index, name in ORDER do
	BITS[name] = bit32.lshift(1, index)
end

-- Bitwise operations come from `bit32` instead of the `&`/`|` operators: the
-- formatter version used here chokes on those operators, while `band`/`bor`
-- compile to the same machine instructions.
const band = bit32.band
const bor = bit32.bor

const Conditions = {}

--- Every condition in the vocabulary. Tests compare it with `bot-characters`.
Conditions.Names = table.clone(ORDER)

--- Bit of a single condition. `0` for an unknown name: what to do about a typo in
--- a config is the caller's business (config tests catch it separately).
function Conditions.Bit(name: string): number
	return BITS[name] or 0
end

--- Mask of a condition list. A list coming from a config is converted once and
--- reused afterwards: configs are static, so a strong cache and the config table
--- itself live exactly as long.
const CACHE: { [any]: number } = {}

function Conditions.Mask(list: { string }?): number
	if not list then return 0 end

	const cached = CACHE[list]
	if cached ~= nil then return cached end

	local mask = 0
	for _, name in list do
		mask = bor(mask, BITS[name] or 0)
	end

	CACHE[list] = mask

	return mask
end

--- Is this condition met?
function Conditions.Has(mask: number, name: string): boolean
	const bit = BITS[name]

	return bit ~= nil and band(mask, bit) ~= 0
end

--- Is at least one condition of the list met?
function Conditions.HasAny(mask: number, list: { string }?): boolean
	return band(mask, Conditions.Mask(list)) ~= 0
end

--- How many conditions of the list are met. Counted with bit tricks instead of
--- scanning the list with `table.find`.
function Conditions.Count(mask: number, list: { string }?): number
	local value = band(mask, Conditions.Mask(list))
	local count = 0

	while value ~= 0 do
		value = band(value, value - 1)
		count += 1
	end

	return count
end

return Conditions
