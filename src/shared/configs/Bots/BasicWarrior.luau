const ReplicatedStorage = game:GetService("ReplicatedStorage")
const BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])

const BasicWarrior: BotsCharacters.BotCharacterConfig = {
	Spec = "Standless",
	MaxHealth = 100,
	Chaotic = 0,
	Aggressive = 0.5,
	Reaction = 0.6,
	Agility = 0.6,
	Debug = false,

	ConditionWeight = 1,
	ComboWeight = 1,

	Skills = {
		["Punch"] = {
			-- One activation = one hit; Punch itself chains up to MaxCombo.
			MaxRepeats = 2,
			-- Matches Punch's ComboResetTime: the chain dies before this expires.
			RepeatResetTime = 1.5,
			Distance = 6,

			ForbiddenConditions = {
				"TARGET_RAGDOLLED",
				"TARGET_BLOCKING",
			},

			PenaltyConditions = {
				"TARGET_ATTACKING",
			},
		},

		["Block"] = {
			PreferredConditions = {
				"TARGET_BLOCKABLE",
				"TARGET_PERFECT_BLOCKABLE",
			},

			ForbiddenConditions = {
				"TARGET_IGNORE_BLOCK",
			},

			HoldWhile = {
				"TARGET_BLOCKABLE",
				"TARGET_PERFECT_BLOCKABLE",
			},

			HoldUntil = {
				"TARGET_PERFECT_BLOCKABLE",
				"TARGET_STUNNED",
				"TARGET_RAGDOLLED",
				"TARGET_BLOCKING",
				"TARGET_IGNORE_BLOCK",
			},
		},

		["Counter"] = {
			Distance = 10,

			RequiredConditions = {
				"TARGET_ATTACKING",
			},

			PreferredConditions = {
				"TARGET_BLOCKABLE",
				"TARGET_ARMORED",
				"TARGET_IGNORE_BLOCK",
			},

			ForbiddenConditions = {
				"TARGET_STUNNED",
				"TARGET_RAGDOLLED",
			},
		},

		["Grab"] = {
			Distance = 6,

			RequiredConditions = {
				"TARGET_BLOCKING",
			},

			PreferredConditions = {
				"TARGET_BLOCKING",
				"TARGET_STUNNED",
			},
		},

		["Footrest"] = {
			Distance = 6,

			ForbiddenConditions = {
				"TARGET_ARMORED",
				"TARGET_RAGDOLLED",
			},

			PreferredConditions = {
				"TARGET_SHORT_RANGE",
			},

			PenaltyConditions = {
				"TARGET_BLOCKING",
			},
		},

		["Uppercut"] = {
			Distance = 8,

			ForbiddenConditions = {
				"TARGET_RAGDOLLED",
			},

			PreferredConditions = {
				"TARGET_STUNNED",
			},

			PenaltyConditions = {
				"TARGET_BLOCKING",
			},
		},

		["Dash"] = {
			Distance = 18,
			Priority = 3,
			PreferredDistance = {
				Min = 8,
				Max = 18,
			},
			MaxRepeats = 1,
			RepeatResetTime = 3,

			PreferredConditions = {
				"TARGET_ATTACKING",
				"TARGET_IGNORE_BLOCK",
			},
		},

		["CircularKick"] = {
			Distance = 6,

			RequiredConditions = {
				"TARGET_RAGDOLLED",
			},
		},

		["DualPistols"] = {
			Distance = 50,

			ForbiddenConditions = {
				"TARGET_RAGDOLLED",
			},
		},

		["KnifeStab"] = {
			Distance = 6,

			PreferredConditions = {
				"TARGET_BLOCKING",
				"TARGET_STUNNED",
			},

			ForbiddenConditions = {
				"TARGET_RAGDOLLED",
			},
		},
	},

	Combos = {
		{
			"Footrest",
			"Punch",
			"Uppercut",
		},

		{
			"KnifeStab",
			"Punch",
			"Uppercut",
			"Dash",
			"CircularKick",
		},

		{
			"Punch",
			"KnifeStab",
			"Grab",
			"CircularKick",
		},

		{
			"Dash",
			"Footrest",
			"Uppercut",
			"Dash",
			"CircularKick",
		},
	},
}

return BasicWarrior
