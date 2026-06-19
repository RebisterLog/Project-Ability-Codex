local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])

local BasicWarrior: BotsCharacters.BotCharacterConfig = {
	Spec = "Standless",
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
			
			HoldUntil = {
				"TARGET_STUNNED",
				"TARGET_ATTACKING",
				"TARGET_RAGDOLLED",
				"TARGET_BLOCKING",
				"TARGET_BLOCK_BREAKING",
				"TARGET_PERFECT_BLOCKING",
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
			}
		},
		
		["Footrest"] = {
			Distance = 6,
			
			RejectedConditions = {
				"TARGET_ARMORED",
				"TARGET_RAGDOLLED",
			}
		},
		
		["Uppercut"] = {
			Distance = 8,

			RejectedConditions = {
				"TARGET_RAGDOLLED",
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
			"Footrest",
			"Punch",
			"Punch",
			"Punch",
			"Uppercut",
		},
		
		{
			"Punch",
			"Punch",
			"Punch",
			"Footrest",
			"Grab",
		},
		
		{
			"Dash",
			"Footrest",
			"Uppercut",
		},
		
		{
			"Dash",
			"Uppercut",
		}
	}
}

return BasicWarrior