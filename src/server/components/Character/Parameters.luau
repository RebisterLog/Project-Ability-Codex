--!native

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Enums = require(ServerScriptService.server.Enums)
const ChargeConfigs = require(ReplicatedStorage.shared.configs.Charges)
const ChargeState = require(ReplicatedStorage.shared.combat.ChargeState)
const AmmoConfigs = require(ReplicatedStorage.shared.configs.Ammo)

type StunState = { Priority: number, Duration: number }

const Mirror = function(value: any): any
	return value
end

const serializeStun = function(value: StunState): { Priority: number, ExpiresAt: number }
	local expiresAt = 0
	if value.Duration > 0 then expiresAt = workspace:GetServerTimeNow() + value.Duration end
	return { Priority = value.Priority, ExpiresAt = expiresAt }
end

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
const LastParser = function(a, b)
	return b
end

-- Different limbs are independent; hitting the same limb again only extends
-- its deadline. The strength of a wound is fixed by the limb type.
const SeveredParser = function(a, b)
	const result = table.clone(a)
	for limb, entry in b do
		if not result[limb] or entry.ExpiresAt > result[limb].ExpiresAt then
			result[limb] = entry
		end
	end
	return result
end

const DefaultAmmo = {}
for id, config in AmmoConfigs do
	DefaultAmmo[id] = { Amount = config.Max, Max = config.Max, NextRegenAt = 0 }
end

return {
	Timescale = { Default = 1, Parser = MultParser },
	IFrames = { Default = 0, Parser = HighestParser },
	DamageMultiplier = { Default = 1, Parser = MultParser },
	DamageReceivalMultiplier = { Default = 1, Parser = MultParser },
	HealMultiplier = { Default = 1, Parser = MultParser },
	HealReceivalMultiplier = { Default = 1, Parser = MultParser },
	CooldownMultiplier = { Default = 1, Parser = MultParser },
	MaxWalkSpeed = { Default = 2048, Parser = LowestParser, Replicate = Mirror },
	MinWalkSpeed = { Default = 0, Parser = HighestParser, Replicate = Mirror },
	MaxJumpPower = { Default = 4096, Parser = LowestParser, Replicate = Mirror },
	NoRotate = { Default = false, Parser = ORParser },

	Stun = {
		Default = {
			Priority = Enums.Stun.None,
			Duration = 0,
		},

		Parser = StunParser,
		Replicate = serializeStun,
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
	Ragdoll = { Default = false, Parser = ORParser, Replicate = Mirror },
	Restand = { Default = false, Parser = ORParser, Replicate = Mirror },
	GodMode = { Default = false, Parser = ORParser },
	NoCollision = { Default = false, Parser = ORParser },
	Restrain = { Default = false, Parser = ORParser, Replicate = Mirror },
	NoSkillCast = { Default = false, Parser = ORParser },

	-- Replicated id of the skill that currently owns the character's global
	-- single-cast lock. Empty when nothing is casting. The client compares it
	-- with the skill it is about to predict so a skill never blocks itself.
	CastingSkill = { Default = "", Parser = LastParser, Replicate = Mirror },

	-- Health cannot drop below one while active. The beat lands as usual (knockback,
	-- ragdoll, stun all apply); excess damage is tracked as debt and paid out when
	-- the last hold is released.
	NoDeath = { Default = false, Parser = ORParser },

	-- Time Stop semantics: the world is frozen, damage does not touch the health bar
	-- at all; the whole attack is queued and replayed in order when the last hold
	-- is released. Healing keeps its order in the same queue.
	DamageHold = { Default = false, Parser = ORParser },

	HamonCharge = {
		Default = table.clone(ChargeConfigs.HamonCharge.Default),
		Parser = LastParser,
		Replicate = ChargeState.Snapshot,
	},

	Ammo = {
		Default = DefaultAmmo,
		Parser = LastParser,
		Replicate = Mirror,
	},

	SeveredLimbs = {
		Default = {},
		Parser = SeveredParser,
		Replicate = Mirror,
	},
}
