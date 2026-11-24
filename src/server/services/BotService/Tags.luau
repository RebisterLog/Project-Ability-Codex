--!native
--!optimize 2

local Conditions = require(script.Parent.Conditions)

local ALIASES: { [string]: string } = {
	PerfectBlockable = "PerfectBlock",
	BlockBreaker = "BlockBreak",
}

local INDEX: { [{ string }]: { [string]: true } } = {}
local MASKS: { [{ string }]: number } = {}

local bor = bit32.bor

local Tags = {}

local function index(tags: { string }?): { [string]: true }?
	if not tags then return nil end

	local set = INDEX[tags]
	if set then return set end

	set = {}
	for _, tag in tags do
		set[tag] = true
	end

	INDEX[tags] = set

	return set
end

function Tags.Has(tags: { string }?, name: string): boolean
	local set = index(tags)
	if not set then return false end
	if set[name] then return true end

	local alias = ALIASES[name]
	return alias ~= nil and set[alias] == true
end

function Tags.Mask(tags: { string }?): number
	if not tags then return 0 end

	local cached = MASKS[tags]
	if cached ~= nil then return cached end

	local set = index(tags) or {}
	local mask = 0

	if set.Hit then mask = bor(mask, Conditions.Bit("TARGET_ATTACKING")) end
	if set.Blockable then mask = bor(mask, Conditions.Bit("TARGET_BLOCKABLE")) end
	if set.IgnoreBlock then mask = bor(mask, Conditions.Bit("TARGET_IGNORE_BLOCK")) end
	if set.BlockBreak then mask = bor(mask, Conditions.Bit("TARGET_BLOCK_BREAKING")) end
	if set.PerfectBlock then mask = bor(mask, Conditions.Bit("TARGET_PERFECT_BLOCKABLE")) end

	MASKS[tags] = mask

	return mask
end

return Tags
