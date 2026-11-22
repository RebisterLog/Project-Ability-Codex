const ReplicatedStorage = game:GetService("ReplicatedStorage")
const BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])

-- Boss config: Star Platinum owns the primary slot (movement, stand and its
-- skills), Hamon owns the secondary one (Jonathan's combat skills). The skill
-- allowlist and combo list are the union of the Jotaro and JonathanJoestar
-- bot configs; overlapping conditions are merged together.
const UltimativeJotaro: BotsCharacters.BotCharacterConfig = {
	Spec = "StarPlatinum",
	SubSpec = "Hamon",

	MaxHealth = 350,
	Chaotic = 0,
	Aggressive = 1,
	Reaction = 1,
	Agility = 1,

	Debug = false,
	ConditionWeight = 1,
	ComboWeight = 1,

	Skills = {
		-- Shared skills: mobility, guard and the basic combo filler.
		["Dash"] = {
			PreferredConditions = {
				"TARGET_ATTACKING",
				"TARGET_IGNORE_BLOCK",
				"TARGET_LARGE_RANGE",
			},
		},

		["Punch"] = {
			Priority = 1,
			Distance = 8,
			PreferredDistance = {
				Min = 5,
				Max = 8,
			},

			ForbiddenConditions = {
				"TARGET_RAGDOLLED",
				"TARGET_BLOCKING",
				"TARGET_PERFECT_BLOCKING",
			},

			PreferredConditions = {
				"TARGET_SHORT_RANGE",
			},

			PenaltyConditions = {
				"TARGET_ATTACKING",
				"TARGET_DODGING",
			},
		},

		["Block"] = {
			PreferredConditions = {
				"TARGET_BLOCKABLE",
				"TARGET_PERFECT_BLOCKABLE",
			},

			ForbiddenConditions = {
				"TARGET_IGNORE_BLOCK",
				"TARGET_BLOCK_BREAKING",
			},

			HoldWhile = {
				"TARGET_ATTACKING",
				"TARGET_BLOCKABLE",
				"TARGET_PERFECT_BLOCKABLE",
			},

			HoldUntil = {
				"TARGET_STUNNED",
				"TARGET_RAGDOLLED",
				"TARGET_BLOCKING",
				"TARGET_PERFECT_BLOCKABLE",
				"TARGET_PERFECT_BLOCKING",
				"TARGET_IGNORE_BLOCK",
				"TARGET_BLOCK_BREAKING",
			},
		},

		-- Star Platinum skills (primary Spec). The key matches the real skill
		-- id in src/server/specs/StarPlatinum.luau.
		["StandBarrage"] = {
			Distance = 10,
			StandSummon = true,
			PreferredDistance = {
				Min = 5,
				Max = 10,
			},
			ForbiddenConditions = {
				"TARGET_RAGDOLLED",
				"TARGET_ARMORED",
			},
			HoldMaxTime = 2,
		},

		["StarStrike"] = {
			StandSummon = true,
			Priority = 2,
			Distance = 6,

			ForbiddenConditions = {
				"TARGET_RAGDOLLED",
			},

			PreferredConditions = {
				"TARGET_STUNNED",
				"TARGET_BLOCKING",
			},
		},

		["StarFinger"] = {
			StandSummon = true,
			Priority = 2,
			Distance = 12,

			ForbiddenConditions = {
				"TARGET_RAGDOLLED",
				"TARGET_BLOCKING",
				"TARGET_PERFECT_BLOCKING",
			},
		},

		["GrabSlam"] = {
			StandSummon = true,
			Priority = 3,
			Distance = 6,

			RequiredConditions = {
				"TARGET_BLOCKING",
			},

			PreferredConditions = {
				"TARGET_BLOCKING",
				"TARGET_STUNNED",
			},
		},

		["GroundSlam"] = {
			StandSummon = true,
			Priority = 4,
			Distance = 12,

			ForbiddenConditions = {
				"TARGET_RAGDOLLED",
			},

			PreferredConditions = {
				"TARGET_ATTACKING",
			},
		},

		-- Hamon skills (SubSpec). Charge only in a free window: the target is
		-- not attacking and no hit is incoming. Released at 50 Hamon, on threat
		-- or after 3 seconds.
		["Charge"] = {
			Distance = 30,
			RequiredConditions = {
				"OWN_HAMON_LOW",
			},
			ForbiddenConditions = {
				"TARGET_ATTACKING",
				"OWN_THREATENED",
			},
			PreferredConditions = {
				"TARGET_STUNNED",
				"TARGET_RAGDOLLED",
				"TARGET_BLOCKING",
				"TARGET_PERFECT_BLOCKING",
			},
			HoldWhile = {
				"OWN_HAMON_LOW",
			},
			HoldUntil = {
				"TARGET_ATTACKING",
				"OWN_THREATENED",
				"OWN_HAMON_READY",
			},
			HoldMaxTime = 3,
			Priority = 1,
		},

		-- BlockBreak = true and Blockable = false: worth spending on a guard.
		["PluckAndLuck"] = {
			Distance = 8,
			PreferredDistance = {
				Min = 5,
				Max = 8,
			},
			ForbiddenConditions = {
				"TARGET_RAGDOLLED",
			},
			PreferredConditions = {
				"TARGET_STUNNED",
				"TARGET_BLOCKING",
				"TARGET_PERFECT_BLOCKING",
			},
			PenaltyConditions = {
				"TARGET_DODGING",
			},
			Priority = 4,
		},

		["SilverPierce"] = {
			Distance = 12,
			PreferredDistance = {
				Min = 6,
				Max = 12,
			},
			ForbiddenConditions = {
				"TARGET_RAGDOLLED",
				"TARGET_BLOCKING",
				"TARGET_PERFECT_BLOCKING",
			},
			PreferredConditions = {
				"TARGET_STUNNED",
			},
			PenaltyConditions = {
				"TARGET_DODGING",
			},
			Priority = 2,
		},

		["YellowOverdrive"] = {
			Distance = 8,
			PreferredDistance = {
				Min = 4,
				Max = 8,
			},
			ForbiddenConditions = {
				"TARGET_RAGDOLLED",
				"TARGET_BLOCKING",
				"TARGET_PERFECT_BLOCKING",
			},
			PreferredConditions = {
				"TARGET_STUNNED",
				"TARGET_SHORT_RANGE",
			},
			PenaltyConditions = {
				"TARGET_ARMORED",
			},
			Priority = 2,
		},

		["SendoHamon"] = {
			Distance = 15,
			ForbiddenConditions = {
				"TARGET_RAGDOLLED",
				"TARGET_BLOCKING",
				"TARGET_PERFECT_BLOCKING",
			},
			PreferredConditions = {
				"TARGET_STUNNED",
			},
			PenaltyConditions = {
				"TARGET_ARMORED",
			},
			Priority = 1,
		},
	},

	-- Openers lean on Dash + StarFinger. Punch fills the gap before one or two
	-- non-ragdoll Hamon skills (YellowOverdrive, SilverPierce); the finisher
	-- always comes back to a Star Platinum ragdoll/ComboEnder.
	Combos = {
		{
			"Dash",
			"StarFinger",
			"Punch",
			"YellowOverdrive",
			"SilverPierce",
			"StarStrike",
		},
		{
			"Dash",
			"StarFinger",
			"Punch",
			"Punch",
			"SilverPierce",
			"GroundSlam",
		},
		{
			"Dash",
			"StarFinger",
			"Punch",
			"YellowOverdrive",
			"GrabSlam",
		},
		{
			"Dash",
			"StarFinger",
			"Punch",
			"Punch",
			"SilverPierce",
			"StarStrike",
		},
		{
			"Dash",
			"Punch",
			"Punch",
			"YellowOverdrive",
			"GroundSlam",
		},
		{
			"StarFinger",
			"Punch",
			"SilverPierce",
			"YellowOverdrive",
			"GrabSlam",
		},
	},
}

return UltimativeJotaro
