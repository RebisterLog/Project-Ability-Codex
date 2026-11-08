const ReplicatedStorage = game:GetService("ReplicatedStorage")
const BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])

const Jotaro: BotsCharacters.BotCharacterConfig = {
	Spec = "StarPlatinum",
	Chaotic = 0,
	Aggressive = 0.5,
	Reaction = 0.6,
	Agility = 0.6,

	Debug = false,
	ComboWeight = 1,

	Skills = {
		["Dash"] = {
			PreferredConditions = {
				"TARGET_ATTACKING",
				"TARGET_IGNORE_BLOCK",
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

		["Barrage"] = {
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
	},

	Combos = {
		{
			"Dash",
			"Punch",
			"Punch",
			"Punch",
			"StarStrike",
		},
		{
			"Dash",
			"StarFinger",
			"Punch",
			"Punch",
			"Punch",
			"GrabSlam",
		},
		{
			"Dash",
			"Punch",
			"Punch",
			"Punch",
			"GroundSlam",
		},
	},
}

return Jotaro