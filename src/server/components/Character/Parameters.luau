--!native

const ServerScriptService = game:GetService("ServerScriptService")
const Enums = require(ServerScriptService.server.Enums)

const HighestParser = function(a, b)
	if a < b then return b end
	return a
end
const LowestParser = function(a, b)
	if a < b then return a end
	return b
end
const MultParser = function(a, b)
	return a * b
end
const StunParser = function(a, b)
	if a.Priority < b.Priority then return b end
	return a
end
-- A stronger wound must not be overwritten by a weaker one, and a weaker one
-- must not vanish when the stronger one is removed: the strongest tick wins.
const BleedingParser = function(a, b)
	if a.Damage > b.Damage then return a end
	return b
end
const ORParser = function(a, b)
	return a or b
end
-- Hamon Charge is a single resource, not a stack of modifiers: the owner object
-- always carries the current snapshot, so the last one wins.
const LastParser = function(a, b)
	return b
end

return {
	Timescale = { Default = 1, Parser = MultParser },
	IFrames = { Default = 0, Parser = HighestParser },
	DamageMultiplier = { Default = 1, Parser = MultParser },
	DamageReceivalMultiplier = { Default = 1, Parser = MultParser },
	HealMultiplier = { Default = 1, Parser = MultParser },
	HealReceivalMultiplier = { Default = 1, Parser = MultParser },
	CooldownMultiplier = { Default = 1, Parser = MultParser },
	MaxWalkSpeed = { Default = 2048, Parser = LowestParser },
	MinWalkSpeed = { Default = 0, Parser = HighestParser },
	MaxJumpPower = { Default = 4096, Parser = LowestParser },

	Stun = {
		Default = {
			Priority = Enums.Stun.None,
			Duration = 0,
		},

		Parser = StunParser,
	},

	Bleeding = {
		Default = {
			Damage = 0,
			Duration = 0,
			Interval = 0,
			Slow = 0,
		},

		Parser = BleedingParser,
	},

	-- Burn: the same shape as `Bleeding`, so the attack that lights it carries the
	-- damage, the pace and the slowdown of the ticks.
	Burning = {
		Default = {
			Damage = 0,
			Duration = 0,
			Interval = 0,
			Slow = 0,
		},

		Parser = BleedingParser,
	},

	Armor = { Default = false, Parser = ORParser },
	Ragdoll = { Default = false, Parser = ORParser },
	GodMode = { Default = false, Parser = ORParser },
	NoCollision = { Default = false, Parser = ORParser },
	Restrain = { Default = false, Parser = ORParser },
	NoSkillCast = { Default = false, Parser = ORParser },

	-- Health cannot drop below one while active. The beat lands as usual (knockback,
	-- ragdoll, stun all apply); excess damage is tracked as debt and paid out when
	-- the last hold is released.
	NoDeath = { Default = false, Parser = ORParser },

	-- Time Stop semantics: the world is frozen, damage does not touch the health bar
	-- at all; the whole attack is queued and replayed in order when the last hold
	-- is released. Healing keeps its order in the same queue.
	DamageHold = { Default = false, Parser = ORParser },

	-- Hamon Charge is a time-based resource. `Amount` is the value at the end of
	-- the hold window; the live value is derived from the timestamps (see
	-- CombatService), so the server never needs a ticking loop.
	HamonCharge = {
		Default = {
			Amount = 0,
			LastGainAt = 0,
			Filling = false,
			FillStartedAt = 0,
			FillStartAmount = 0,
			Max = 100,
			FillRate = 20,
			DecayRate = 10,
			HoldSeconds = 5,
		},

		Parser = LastParser,
	},
}
