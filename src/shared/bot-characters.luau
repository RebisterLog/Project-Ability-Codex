const SkillCharacters = {
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

const SkillConditions = {
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

	-- Own state of the bot, not of the target. Used by resource skills (Charge):
	-- the bot only charges while its Hamon is below the target level, and drops
	-- the hold as soon as it is ready or a hit is incoming.
	OWN_HAMON_LOW = "OWN_HAMON_LOW",
	OWN_HAMON_READY = "OWN_HAMON_READY",
	OWN_THREATENED = "OWN_THREATENED",
}

export type SkillCharacter = keyof<typeof(SkillCharacters)>
export type SkillCondition = keyof<typeof(SkillConditions)>
export type SkillCombo = { string }

-- Настройки одного скилла в конфиге бота.
--
-- Условия делятся на две жёсткие группы и две мягкие. Жёсткие не участвуют в
-- подсчёте приоритета: они только исключают скилл из выбора. Мягкие копятся в
-- число, по которому выбирается победитель (см. BotService/SkillPriority).
export type SkillPreference = {
	-- Жёсткая дальность: дальше скилл в выборе не участвует.
	Distance: number?,

	-- Мягкая полоса: попадание в неё даёт `+ConditionWeight`.
	PreferredDistance: {
		Min: number?,
		Max: number?,
	}?,

	-- Жёсткие группы. Любое нарушение исключает скилл из выбора целиком.
	RequiredConditions: { SkillCondition }?,
	ForbiddenConditions: { SkillCondition }?,

	-- Мягкие группы. Каждое выполненное условие даёт `+ConditionWeight`
	-- или `-ConditionWeight` соответственно.
	PreferredConditions: { SkillCondition }?,
	PenaltyConditions: { SkillCondition }?,

	-- Аварийный релиз: пока скилл удерживается ботом (Block), появление любого
	-- из этих условий его немедленно отпускает.
	HoldUntil: { SkillCondition }?,

	-- Основной механизм удержания: бот держит скилл, пока выполнено ХОТЯ БЫ ОДНО
	-- из этих условий, и отпускает, когда не выполнено ни одного. Полярность
	-- обратна `HoldUntil`: то «отпусти, когда произойдёт», это «держи, пока есть».
	--
	-- Если поле не задано, удержание страхуется пересчётом: скилл отпускается,
	-- когда перестаёт быть лучшим кандидатом (см. SkillPriority.ShouldRelease).
	HoldWhile: { SkillCondition }?,

	-- Жёсткий предел удержания в секундах. Страхует от «забыл отпустить»:
	-- по истечении бот принудительно вызывает DeactivateSkill.
	HoldMaxTime: number?,

	-- Сдвиг приоритета, если автору не хватает условий для разведения скиллов.
	Priority: number?,

	-- Требование состояния стенда: true = стенд должен быть активирован,
	-- false = стенд должен быть деактивирован. При несовпадении бот вызывает
	-- Summon и откладывает активацию целевого скилла.
	StandSummon: boolean?,
}

export type BotCharacterConfig = {
	-- Characteristics. `SubSpec` goes to the secondary slot: the bot gets its
	-- skills from it while the primary `Spec` owns movement/animations.
	Spec: string,
	SubSpec: string?,

	-- Applied on every spawn: MaxHealth is written first, then Health is filled
	-- to the same value. Falls back to the rig default when omitted.
	MaxHealth: number?,

	Chaotic: number,
	Aggressive: number,
	Reaction: number,
	Agility: number,
	Debug: boolean?,

	-- Вес одного мягкого условия и бонус за скилл из текущего комбо.
	ConditionWeight: number?,
	ComboWeight: number?,

	-- Skills conditions
	Skills: {
		[string]: SkillPreference,
	},

	Combos: { SkillCombo },
}

return {
	SkillCharacters = SkillCharacters,
	SkillConditions = SkillConditions,
}
