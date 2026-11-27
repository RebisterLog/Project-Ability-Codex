const ReplicatedStorage = game:GetService("ReplicatedStorage")
const BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])

const Dio: BotsCharacters.BotCharacterConfig = {
	Spec = "TheWorld",
	MaxHealth = 100,
	Chaotic = 0,
	Aggressive = 0.5,
	Reaction = 0.6,
	Agility = 0.6,

	ConditionWeight = 1,
	ComboWeight = 1,

	Skills = {
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
		},

		["StopSign"] = {
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

		["Punch"] = {
			-- One activation = one hit; Punch itself chains up to MaxCombo.
			MaxRepeats = 2,
			-- Matches Punch's ComboResetTime: the chain dies before this expires.
			RepeatResetTime = 1.5,
			Priority = 1,
			Distance = 8,
			PreferredDistance = {
				Min = 5,
				Max = 8,
			},

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
			},
		},

		["Knives"] = {
			-- AimRequired skills get a server-generated AimPoint from Bot.ActivateSkill.
			Distance = 30,
			Priority = 2,

			ForbiddenConditions = {
				"TARGET_RAGDOLLED",
			},
		},

		["LegBarrage"] = {
			StandSummon = true,
			Priority = 2,
			Distance = 8,
			PreferredDistance = {
				Min = 5,
				Max = 8,
			},

			ForbiddenConditions = {
				"TARGET_RAGDOLLED",
				"TARGET_ARMORED",
			},
		},

		["DistanceSlam"] = {
			-- Always casts on the nearest enemy within 50 studs and spends its cooldown.
			StandSummon = true,
			Priority = 3,
			Distance = 50,

			ForbiddenConditions = {
				"TARGET_RAGDOLLED",
			},
		},
	},

	Combos = {
		{
			"Punch",
			"Knives",
		},
	},
}

return Dio
