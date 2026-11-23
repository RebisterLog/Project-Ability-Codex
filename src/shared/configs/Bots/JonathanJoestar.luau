const ReplicatedStorage = game:GetService("ReplicatedStorage")
const BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])

const JonathanJoestar: BotsCharacters.BotCharacterConfig = {
	-- Standless owns movement/animations; all combat skills, including Charge,
	-- live in the JonathanHamon SubSpec. Only those skills are in the allowlist below.
	Spec = "Standless",
	SubSpec = "JonathanHamon",

	MaxHealth = 100,
	Chaotic = 0.1,
	Aggressive = 0.5,
	Reaction = 0.7,
	Agility = 0.6,

	ConditionWeight = 1,
	ComboWeight = 1,

	Skills = {
		-- Shared Standless skills: mobility, guard and the basic combo filler.
		["Dash"] = {
			PreferredConditions = {
				"TARGET_ATTACKING",
				"TARGET_IGNORE_BLOCK",
				"TARGET_LARGE_RANGE",
			},
		},

		-- Punch is fully blockable: never spend it on a guard or a perfect block.
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

		-- Charge only in a free window: the target is not attacking, not stunned
		-- and no hit is incoming. A stunned target is a combo window, so it is
		-- never spent on charging. Released at 50 Hamon, on stun, on threat or
		-- after 2 seconds.
		["Charge"] = {
			Distance = 30,
			RequiredConditions = {
				"OWN_HAMON_LOW",
			},
			ForbiddenConditions = {
				"TARGET_ATTACKING",
				"TARGET_STUNNED",
				"OWN_THREATENED",
			},
			PreferredConditions = {
				"TARGET_RAGDOLLED",
				"TARGET_BLOCKING",
				"TARGET_PERFECT_BLOCKING",
			},
			HoldWhile = {
				"OWN_HAMON_LOW",
			},
			HoldUntil = {
				"TARGET_ATTACKING",
				"TARGET_STUNNED",
				"OWN_THREATENED",
				"OWN_HAMON_READY",
			},
			HoldMaxTime = 2,
			Priority = 1,
		},

		-- The opener has BlockBreak = true and Blockable = false, so this is the
		-- only Hamon attack worth spending on a guarding target.
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

		-- Blockable = true, BlockBreak = false: useless into a held guard.
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

		-- Barrage is Blockable and has no BlockBreak: every hit would be eaten.
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

		-- Only the frame-125 release ignores block; the wave ticks are blockable.
		["SendoHamon"] = {
			Distance = 10,
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

	Combos = {
		{
			"PluckAndLuck",
			"SilverPierce",
			"YellowOverdrive",
		},
		{
			"SilverPierce",
			"SendoHamon",
		},
		{
			"Dash",
			"Punch",
			"Punch",
			"PluckAndLuck",
			"SilverPierce",
		},
		{
			"Dash",
			"Punch",
			"Punch",
			"YellowOverdrive",
			"PluckAndLuck",
		},
		{
			"Dash",
			"SilverPierce",
			"Punch",
			"Punch",
			"SendoHamon",
		},
		{
			"Punch",
			"Punch",
			"PluckAndLuck",
			"SilverPierce",
			"YellowOverdrive",
		},
	},
}

return JonathanJoestar
