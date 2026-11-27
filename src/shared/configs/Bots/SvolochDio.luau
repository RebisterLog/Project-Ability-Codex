const ReplicatedStorage = game:GetService("ReplicatedStorage")
const BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])

-- Boss config built on Dio: The World owns the primary slot (movement, stand
-- and its skills), JonathanHamon owns the secondary one. The skill allowlist
-- is the union of the Dio and JonathanJoestar bot configs; overlapping
-- conditions are merged. Charge is in the allowlist so the bot can charge
-- Hamon by priority, but it stays out of the combo plans. No alternate skins.
const SvolochDio: BotsCharacters.BotCharacterConfig = {
	Spec = "TheWorld",
	SubSpec = "JonathanHamon",

	MaxHealth = 350,
	Chaotic = 0,
	Aggressive = 0.5,
	Reaction = 0.6,
	Agility = 0.6,

	ConditionWeight = 1,
	ComboWeight = 1,

	Skills = {
		-- Shared skills: mobility, guard and the basic combo filler.
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

		-- The World skills (primary Spec).
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

		-- Hamon skills (SubSpec). Charge only in a free window: the target is
		-- not attacking, not stunned and no hit is incoming. It is a held Buff,
		-- so it stays out of the combo plans but is still selectable by priority.
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

	-- Dash opens; StandBarrage, LegBarrage, YellowOverdrive, SilverPierce,
	-- Knives and Punch fill the middle; the ragdoll skills close the plan.
	-- StopSign is tagged ComboStarter but applies Ragdoll, so it is an ender.
	Combos = {
		-- Pure The World
		{
			"Dash",
			"StandBarrage",
			"Punch",
			"LegBarrage",
			"StopSign",
		},

		-- Mixed: The World + Hamon
		{
			"Dash",
			"SilverPierce",
			"StandBarrage",
			"Punch",
			"PluckAndLuck",
		},
		{
			"Dash",
			"Knives",
			"YellowOverdrive",
			"Punch",
			"StopSign",
		},
		{
			"Dash",
			"Punch",
			"SilverPierce",
			"LegBarrage",
			"SendoHamon",
		},
		{
			"Dash",
			"StandBarrage",
			"SilverPierce",
			"Punch",
			"StopSign",
		},
		{
			"Dash",
			"Knives",
			"Punch",
			"YellowOverdrive",
			"PluckAndLuck",
		},
		{
			"Dash",
			"Punch",
			"StandBarrage",
			"SilverPierce",
			"DistanceSlam",
		},
		{
			"Dash",
			"SilverPierce",
			"LegBarrage",
			"Punch",
			"StopSign",
		},
	},
}

return SvolochDio
