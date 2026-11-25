--!native
--!optimize 2

-- The order assigns the bit numbers and must stay stable across restarts.
local ORDER = {
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

	"OWN_HAMON_LOW",
	"OWN_HAMON_READY",
	"OWN_THREATENED",
}

local BITS: { [string]: number } = {}

for index, name in ORDER do
	BITS[name] = bit32.lshift(1, index)
end

-- Bitwise operations come from `bit32` instead of the `&`/`|` operators: the
-- formatter version used here chokes on those operators, while `band`/`bor`
-- compile to the same machine instructions.
local band = bit32.band
local bor = bit32.bor

local Conditions = {}

Conditions.Names = table.clone(ORDER)

function Conditions.Bit(name: string): number
	return BITS[name] or 0
end

-- Config lists are static, so caching masks by list identity is safe.
local CACHE: { [{ string }]: number } = {}

function Conditions.Mask(list: { string }?): number
	if not list then return 0 end

	local cached = CACHE[list]
	if cached ~= nil then return cached end

	local mask = 0
	for _, name in list do
		mask = bor(mask, BITS[name] or 0)
	end

	CACHE[list] = mask

	return mask
end

function Conditions.Has(mask: number, name: string): boolean
	local bit = BITS[name]

	return bit ~= nil and band(mask, bit) ~= 0
end

function Conditions.HasAny(mask: number, list: { string }?): boolean
	return band(mask, Conditions.Mask(list)) ~= 0
end

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
