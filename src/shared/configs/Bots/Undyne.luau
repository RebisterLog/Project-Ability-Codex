local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])

local Undyne: BotsCharacters.BotCharacterConfig = {
	Spec = "Undyne",
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
			}
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
		},
		
		["Barrage"] = {
			Distance = 10,
		
			RejectedConditions = {
				"TARGET_RAGDOLLED",
				"TARGET_ARMORED",
			}
		},
		
		["ArcSpearStrike"] = {
			Distance = 7,
			
			RejectedConditions = {
				"TARGET_RAGDOLLED",
				"TARGET_PERFECT_BLOCKING",
			}
		},
		
		["Dash"] = {
			--Distance = 15,
			--RequiredConditions = {
			--	"TARGET_IGNORE_BLOCK",
			--	"TARGET_ATTACKING",
			--}
		},
	},
	
	Combos = {
		{
			"Punch",
			"Punch",
			"Punch",
			"Barrage"
		},
		
		{
			"Punch",
			"Punch",
			"Punch",
			"ArcSpearStrike"
		},
		
		{
			"Dash",
			"ArcSpearStrike",
		},
		
		{
			"Dash",
			"Punch",
			"Punch",
			"ArcSpearStrike",
		},
	}
}

return Undyne