--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Conditions = require(script.Parent.Conditions)
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Enums = require(ServerScriptService.server.Enums)
local types = require(ServerScriptService.server.types)

--- Perception of the target: distance and a mask of conditions.
---
--- Refreshed every tick but without a single allocation: conditions accumulate in
--- bits instead of an array of strings. The previous version built an array and
--- ran `table.find` over it for every active skill of the target, which on ten
--- bots means dozens of string comparisons per frame instead of a few bitwise
--- operations.

-- Boundaries of `TARGET_SHORT_RANGE` / `TARGET_MIDDLE_RANGE` / `TARGET_LARGE_RANGE`.
local RANGE_SHORT = 10
local RANGE_MIDDLE = 20

-- Charge target: Pluck&Luck spends 50 to apply its Burn, so the bot only
-- considers itself "ready" once that threshold is reached.
local HAMON_READY = 50

-- Bitwise operations come from `bit32`: the formatter version used here chokes on
-- the `&` and `|` operators, while `band`/`bor` compile to the same instructions.
local bor = bit32.bor

local BITS = {
	SHORT_RANGE = Conditions.Bit("TARGET_SHORT_RANGE"),
	MIDDLE_RANGE = Conditions.Bit("TARGET_MIDDLE_RANGE"),
	LARGE_RANGE = Conditions.Bit("TARGET_LARGE_RANGE"),

	ARMORED = Conditions.Bit("TARGET_ARMORED"),
	ATTACKING = Conditions.Bit("TARGET_ATTACKING"),
	STUNNED = Conditions.Bit("TARGET_STUNNED"),
	RAGGEDOLLED = Conditions.Bit("TARGET_RAGDOLLED"),
	DODGING = Conditions.Bit("TARGET_DODGING"),

	BLOCKING = Conditions.Bit("TARGET_BLOCKING"),
	PERFECT_BLOCKING = Conditions.Bit("TARGET_PERFECT_BLOCKING"),
	BLOCKABLE = Conditions.Bit("TARGET_BLOCKABLE"),
	PERFECT_BLOCKABLE = Conditions.Bit("TARGET_PERFECT_BLOCKABLE"),
	IGNORE_BLOCK = Conditions.Bit("TARGET_IGNORE_BLOCK"),
	BLOCK_BREAKING = Conditions.Bit("TARGET_BLOCK_BREAKING"),

	OWN_HAMON_LOW = Conditions.Bit("OWN_HAMON_LOW"),
	OWN_HAMON_READY = Conditions.Bit("OWN_HAMON_READY"),
	OWN_THREATENED = Conditions.Bit("OWN_THREATENED"),
}

export type SenseProperties = {
	Character: types.Character,
	Target: types.Character?,

	Mask: number,
	Distance: number,
}

export type Sense = SenseProperties

local Sense = {}
Sense.__index = Sense

function Sense.new(character: types.Character): Sense
	return setmetatable({
		Character = character,
		Target = nil,
		Mask = 0,
		Distance = 0,
	}, Sense)
end

function Sense:SetTarget(target: types.Character?)
	self.Target = target
	self:Refresh()
end

function Sense:ClearTarget()
	self.Target = nil
	self.Mask = 0
	self.Distance = 0
end

--- Conditions derived from the tags of the active skills of the target.
---
--- `PerfectBlockable` and `PerfectBlock` are the same condition: the vocabulary
--- exports the key, while skills are written using the value. Both spellings are
--- accepted so that a hand-written skill cannot silently disagree with the bot.
local function TagMask(tags: { string }?): number
	if not tags then return 0 end

	local mask = 0

	if table.find(tags, "Hit") then mask = bor(mask, BITS.ATTACKING) end
	if table.find(tags, "Blockable") then mask = bor(mask, BITS.BLOCKABLE) end
	if table.find(tags, "IgnoreBlock") then mask = bor(mask, BITS.IGNORE_BLOCK) end

	-- Skills spell this tag both ways in the repo (the vocabulary key and its
	-- value); guarding against a breaker is pointless.
	if table.find(tags, "BlockBreak") or table.find(tags, "BlockBreaker") then
		mask = bor(mask, BITS.BLOCK_BREAKING)
	end

	if table.find(tags, "PerfectBlockable") or table.find(tags, "PerfectBlock") then
		mask = bor(mask, BITS.PERFECT_BLOCKABLE)
	end

	return mask
end

--- Is the target winding up an attack: any active skill carries the `Hit` tag.
---
--- This is a condition, not "does anything look active": a held guard or an escape
--- keeps the target active indefinitely, and the bot used to stay in the defensive
--- posture forever because of it.
function Sense.IsAttacking(self: Sense): boolean
	return Conditions.Has(self.Mask, "TARGET_ATTACKING")
end

function Sense.Refresh(self: Sense)
	local target = self.Target

	if not target or not target.RootPart or not self.Character.RootPart then
		self.Mask = 0
		self.Distance = 0

		return
	end

	local mask = 0

	-- Own state shares the mask with the target conditions: a skill config can
	-- gate a resource skill on "my Hamon is low" as well as on the enemy.
	const charge = Crane:GetService("CombatService"):GetCharge(self.Character, "HamonCharge")
	if charge < HAMON_READY then
		mask = bor(mask, BITS.OWN_HAMON_LOW)
	else
		mask = bor(mask, BITS.OWN_HAMON_READY)
	end

	local distance = (target.RootPart.Position - self.Character.RootPart.Position).Magnitude
	self.Distance = distance

	if distance <= RANGE_SHORT then
		mask = bor(mask, BITS.SHORT_RANGE)
	elseif distance <= RANGE_MIDDLE then
		mask = bor(mask, BITS.MIDDLE_RANGE)
	else
		mask = bor(mask, BITS.LARGE_RANGE)
	end

	if target:GetParameter("Armor") == true then mask = bor(mask, BITS.ARMORED) end
	if target:GetParameter("Ragdoll") == true then mask = bor(mask, BITS.RAGGEDOLLED) end

	local stun = target:GetParameter("Stun")
	if stun and stun.Priority > Enums.Stun.None then mask = bor(mask, BITS.STUNNED) end

	if target:GetParameter("IFrames") >= Enums.IFrames.Dodge then mask = bor(mask, BITS.DODGING) end

	local block = target.Block

	if block.Blocking then
		mask = bor(mask, BITS.BLOCKING)

		if (os.clock() - block.PerfectBlockTime) <= block.PerfectBlockWindow then
			mask = bor(mask, BITS.PERFECT_BLOCKING)
		end
	end

	-- Single pass over the active skills: `TARGET_ATTACKING` is set by the `Hit` tag.
	-- A player can keep all combat skills in a SubSpec, so both slots matter.
	for _, spec in { target.Spec, target.SubSpec } do
		if not spec then continue end

		const _, activeSkills = spec:CheckActiveSkills()

		for _, skill in activeSkills do
			mask = bor(mask, TagMask(skill.Data.SkillCharacters))
		end
	end

	self.Mask = mask
end

return Sense
