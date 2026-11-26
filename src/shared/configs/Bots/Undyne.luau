const ReplicatedStorage = game:GetService("ReplicatedStorage")
const BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])

const Undyne: BotsCharacters.BotCharacterConfig = {
	Spec = "Undyne",
	MaxHealth = 100,
	Chaotic = 0,
	Aggressive = 0.5,
	Reaction = 0.6,
	Agility = 0.6,

	ConditionWeight = 1,
	ComboWeight = 1,

	Skills = {
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

		["ArcSpearStrike"] = {
			Distance = 7,
			PreferredDistance = {
				Min = 5,
				Max = 7,
			},

			ForbiddenConditions = {
				"TARGET_RAGDOLLED",
				"TARGET_PERFECT_BLOCKING",
			},
		},

		["WaitALittleBit"] = {
			Distance = 8,

			RequiredConditions = {
				"TARGET_RAGDOLLED",
			},
		},

		["Dash"] = {
			Distance = 18,
			Priority = 3,
			PreferredDistance = {
				Min = 12,
				Max = 18,
			},
			MaxRepeats = 1,
			RepeatResetTime = 3,

			PreferredConditions = {
				"TARGET_ATTACKING",
				"TARGET_IGNORE_BLOCK",
			},
		},
	},

	Combos = {
		{
			"Punch",
			"Barrage",
		},

		{
			"Punch",
			"ArcSpearStrike",
			"WaitALittleBit",
		},

		{
			"Dash",
			"ArcSpearStrike",
			"WaitALittleBit",
		},

		{
			"Dash",
			"Punch",
			"ArcSpearStrike",
			"WaitALittleBit",
		},
	},
}

return Undyne
