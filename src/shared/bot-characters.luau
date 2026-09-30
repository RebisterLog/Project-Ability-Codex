local SkillCharacters = {
	Hit = "Hit",
	Ragdoll = "Ragdoll",
	Defense = "Defense",
	Escape = "Escape",
	Stun = "Stun",
	Counter = "Counter",

	ComboStarter = "ComboStarter",
	ComboExtender = "ComboExtender",
	ComboEnder = "ComboEnder",

	Solo = "Solo",
	Automatic = "Automatic",

	Buff = "Buff",
	Debuff = "Debuff",
	Heal = "Heal",

	Grab = "Grab",

	Blockable = "Blockable",
	IgnoreBlock = "IgnoreBlock",
	BlockBreaker = "BlockBreak",
	PerfectBlockable = "PerfectBlock",
	Armored = "Armored",

	Projectile = "Projectile",
}

local SkillConditions = {
	TARGET_SHORT_RANGE = "TARGET_SHORT_RANGE",
	TARGET_MIDDLE_RANGE = "TARGET_MIDDLE_RANGE",
	TARGET_LARGE_RANGE = "TARGET_LARGE_RANGE",

	TARGET_ARMORED = "TARGET_ARMORED",
	TARGET_ATTACKING = "TARGET_ATTACKING",

	TARGET_PERFECT_BLOCKABLE = "TARGET_PERFECT_BLOCKABLE",
	TARGET_BLOCKABLE = "TARGET_BLOCKABLE",

	TARGET_IGNORE_BLOCK = "TARGET_IGNORE_BLOCK",
	TARGET_BLOCK_BREAKING = "TARGET_BLOCK_BREAKING",
	TARGET_PERFECT_BLOCKING = "TARGET_PERFECT_BLOCKING",
	TARGET_BLOCKING = "TARGET_BLOCKING",

	TARGET_STUNNED = "TARGET_STUNNED",
	TARGET_RAGDOLLED = "TARGET_RAGDOLLED",

	TARGET_DODGING = "TARGET_DODGING",
	TARGET_INTERRUPTABLE = "TARGET_INTERRUPTABLE",
}

export type SkillCharacter = keyof<typeof(SkillCharacters)>
export type SkillCondition = keyof<typeof(SkillConditions)>
export type SkillCombo = { string }

export type BotCharacterConfig = {
	-- Characteristics
	Spec: string,
	Chaotic: number,
	Aggressive: number,
	Reaction: number,
	Agility: number,

	-- Skills conditions
	Skills: {
		[string]: {
			Distance: number?,
			RequiredConditions: { SkillCondition }?,
			RejectedConditions: { SkillCondition }?,
			HoldUntil: { SkillCondition }?,
		},
	},

	Combos: { SkillCombo },
}

return {
	SkillCharacters = SkillCharacters,
	SkillConditions = SkillConditions,
}
