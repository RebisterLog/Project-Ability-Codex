--!native
--!optimize 2

local ServerScriptService = game:GetService("ServerScriptService")
local CombatSnapshot = require(script.Parent.CombatSnapshot)
local Conditions = require(script.Parent.Conditions)
local Enums = require(ServerScriptService.server.Enums)
local types = require(ServerScriptService.server.types)

local RANGE_SHORT = 10
local RANGE_MIDDLE = 20
local HAMON_READY = 50

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

export type Sense = {
	Character: types.Character,
	Target: types.Character?,
	LastTick: number,
	Mask: number,
	Distance: number,
}

local Sense = {}
Sense.__index = Sense

type CombatServiceLike = {
	GetCharge: (self: CombatServiceLike, character: types.Character, id: string) -> number,
}

local combatService: CombatServiceLike? = nil

function Sense:Configure(services: { CombatService: CombatServiceLike })
	combatService = services.CombatService
end

function Sense.new(character: types.Character): Sense
	return setmetatable({
		Character = character,
		Target = nil,
		LastTick = -1,
		Mask = 0,
		Distance = 0,
	}, Sense) :: Sense
end

function Sense:SetTarget(target: types.Character?)
	self.Target = target
	self:Refresh(nil)
end

function Sense:ClearTarget()
	self.Target = nil
	self.LastTick = -1
	self.Mask = 0
	self.Distance = 0
end

function Sense.IsAttacking(self: Sense): boolean
	return Conditions.Has(self.Mask, "TARGET_ATTACKING")
end

function Sense:Refresh(tickId: number?)
	if tickId ~= nil and self.LastTick == tickId then return end
	self.LastTick = tickId or -1

	local target = self.Target

	if not target or not target.RootPart or not self.Character.RootPart then
		self.Mask = 0
		self.Distance = 0
		return
	end

	local mask = 0
	CombatSnapshot:Get(self.Character):Refresh(self.Character, self.LastTick)

	local charge = combatService and combatService:GetCharge(self.Character, "HamonCharge") or 0

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

	local state = CombatSnapshot:Get(target):Refresh(target, self.LastTick)

	if state.Armor then mask = bor(mask, BITS.ARMORED) end
	if state.Ragdoll then mask = bor(mask, BITS.RAGGEDOLLED) end
	if state.Stun > Enums.Stun.None then mask = bor(mask, BITS.STUNNED) end
	if state.IFrames >= Enums.IFrames.Dodge then mask = bor(mask, BITS.DODGING) end

	local block = target.Block
	if block.Blocking then
		mask = bor(mask, BITS.BLOCKING)

		-- Block stamps this time with os.clock(), so this comparison must stay
		-- on the same clock even though the rest of the bot uses server time.
		if (os.clock() - block.PerfectBlockTime) <= block.PerfectBlockWindow then
			mask = bor(mask, BITS.PERFECT_BLOCKING)
		end
	end

	mask = bor(mask, state.ActiveTagMask)
	self.Mask = mask
end

return Sense
