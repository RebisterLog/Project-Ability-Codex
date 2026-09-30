local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])

local Dio: BotsCharacters.BotCharacterConfig = {
	Spec = "TheWorld",
	Chaotic = 0,
	Aggressive = 0.5,
	Reaction = 0.6,
	Agility = 0.6,

	Skills = {
		["Punch"] = {
			Distance = 8,

			RejectedConditions = {
				"TARGET_ATTACKING",
				"TARGET_RAGDOLLED",
				"TARGET_BLOCKING",
			},
		},

		["Block"] = {
			RequiredConditions = {
				"TARGET_ATTACKING",
				"TARGET_PERFECT_BLOCKABLE",
			},

			RejectedConditions = {
				"TARGET_IGNORE_BLOCK",
			},
		},

		["Grab"] = {
			Distance = 6,

			RequiredConditions = {
				"TARGET_BLOCKING",
			},

			RejectedConditions = {
				--"TARGET_RAGDOLLED",
				--"TARGET_ATTACKING",
				--"TARGET_ARMORED",
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
