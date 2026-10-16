const ReplicatedStorage = game:GetService("ReplicatedStorage")
const BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])

const Dio: BotsCharacters.BotCharacterConfig = {
	Spec = "TheWorld",
	Chaotic = 0,
	Aggressive = 0.5,
	Reaction = 0.6,
	Agility = 0.6,

	ConditionWeight = 1,
	ComboWeight = 1,

	Skills = {
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

		["Grab"] = {
			Distance = 6,
			PreferredDistance = {
				Min = 4,
				Max = 6,
			},

			RequiredConditions = {
				"TARGET_BLOCKING",
			},

			PreferredConditions = {
				"TARGET_BLOCKING",
				"TARGET_STUNNED",
			},
		},
	},

	Combos = {
		{
			"Punch",
			"Punch",
			"Punch",
			"Punch",
		},
	},
}

return Dio
