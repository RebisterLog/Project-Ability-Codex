const ReplicatedStorage = game:GetService("ReplicatedStorage")
const BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])

-- Boss config: Standless owns the primary slot (movement, basic combo and
-- weapons), JonathanHamon owns the secondary one (Jonathan's combat skills)
-- with the "PAC Hamon" skin applied. The skill allowlist and combo list are
-- the union of the BasicWarrior and
-- JonathanJoestar bot configs; overlapping conditions are merged together.
-- `Grab` is intentionally absent: it is commented out in the Standless spec.
const SuperStandless: BotsCharacters.BotCharacterConfig = {
	Spec = "Standless",
	SubSpec = "JonathanHamon",
	SubSpecSkin = "PAC Hamon",

	MaxHealth = 350,
	Chaotic = 0,
	Aggressive = 0.5,
	Reaction = 0.6,
	Agility = 0.6,

	Debug = false,
	ConditionWeight = 1,
	ComboWeight = 1,

	Skills = {
		-- Shared Standless skills: mobility, guard and combo filler.
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
				"TARGET_LARGE_RANGE",
			},
		},

		["Punch"] = {
			MaxRepeats = 2,
			RepeatResetTime = 1.5,
			Priority = 2,
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

		-- Standless-only skills (primary Spec).
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

		-- JonathanHamon skills (SubSpec). Charge only in a free window: the target is
		-- not attacking, not stunned and no hit is incoming. A stunned target is
		-- a combo window, so it is never spent on charging. Released at 50 Hamon,
		-- on stun, on threat or after 2 seconds.
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

	-- Punch (max two per plan) and KnifeStab fill the middle; Footrest and the
	-- other ragdoll skills close the plan.
	Combos = {
		-- Pure Hamon
		{
			"SilverPierce",
			"YellowOverdrive",
			"PluckAndLuck",
		},

		-- Mixed: Standless + Hamon
		{
			"Dash",
			"Punch",
			"YellowOverdrive",
			"KnifeStab",
			"Uppercut",
		},
		{
			"Counter",
			"KnifeStab",
			"Punch",
			"SilverPierce",
			"Footrest",
		},
		{
			"Dash",
			"KnifeStab",
			"Punch",
			"Footrest",
		},
		{
			"Dash",
			"KnifeStab",
			"Punch",
			"YellowOverdrive",
			"SendoHamon",
		},
		{
			"Counter",
			"Punch",
			"SilverPierce",
			"YellowOverdrive",
			"Uppercut",
		},
		{
			"Dash",
			"Punch",
			"KnifeStab",
			"DualPistols",
			"Footrest",
		},
		{
			"Counter",
			"KnifeStab",
			"Punch",
			"YellowOverdrive",
			"SendoHamon",
		},
	},
}

return SuperStandless
