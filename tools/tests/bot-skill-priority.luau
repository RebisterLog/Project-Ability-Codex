--!strict
--- Тесты `BotService/SkillPriority` и конфигов ботов.
---
---   lune run tools/tests/bot-skill-priority.luau
---
--- Скорер не общается с Roblox, но тянет `ReplicatedStorage` ради типов конфига, а
--- `lune` не даёт подменить глобалы другому скрипту. Поэтому берётся настоящий
--- исходник модуля, и в нём заменяются ровно две строки — получение сервиса и
--- `require` типов. Логика скоринга при этом тестируется как есть, без копии.

local botCharacters = require("../../src/shared/bot-characters")
local fs = require("@lune/fs")

--- Строки, которые нельзя выполнить вне Roblox. Каждая обязана встретиться
--- ровно один раз: если модуль перепишут, тест упадёт на подстановке, а не
--- молча начнёт проверять устаревший код.
local STUBS: { { pattern: string, replacement: string } } = {
	{
		pattern = [[local ReplicatedStorage = game:GetService%("ReplicatedStorage"%)]],
		replacement = "local ReplicatedStorage = nil",
	},
	{
		pattern = [[require%(ReplicatedStorage%.shared%["bot%-characters"%]%)]],
		replacement = "{}",
	},
}

--- Загружает конфиг или модуль бота, подменяя Roblox-строки. Типы из
--- `bot-characters` нужны только анализатору, в рантайме таблица пустая.
local function loadModule(path: string): any
	local source = fs.readFile(path)

	for _, stub in STUBS do
		local result = string.gsub(source, stub.pattern, stub.replacement)
		assert(result ~= source, `stub did not match in {path}: {stub.pattern}`)

		source = result
	end

	local chunk = loadstring(source, `={path}`)
	assert(chunk ~= nil, `failed to compile {path}`)

	local module = chunk()
	assert(type(module) == "table", `{path} did not return a table`)

	return module
end

local SkillPriority = loadModule("src/server/services/BotService/SkillPriority.luau")

local CONFIG_FILES = {
	"src/shared/configs/Bots/Undyne.luau",
	"src/shared/configs/Bots/Gerson.luau",
	"src/shared/configs/Bots/Dio.luau",
	"src/shared/configs/Bots/BasicWarrior.luau",
}

local passed = 0
local failures: { string } = {}

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		return
	end

	table.insert(failures, if detail ~= nil then `{name}: {detail}` else name)
end

local function equal(name: string, actual: any, expected: any)
	check(name, actual == expected, `expected {tostring(expected)}, got {tostring(actual)}`)
end

local function candidate(id: string): any
	return { Data = { Id = id } }
end

--- Список кандидатов. Принимает массив, а не `...`: итерировать `...` нельзя,
--- когда вызвали с одним аргументом — там это сама строка, а не таблица.
local function candidates(ids: { string }): { any }
	local list = {}
	for _, id in ids do
		table.insert(list, candidate(id))
	end
	return list
end

--- Минимальный конфиг: веса по единице, пустое комбо.
local function makeConfig(skills: any, weights: any?): any
	return {
		Spec = "Test",
		Chaotic = 0,
		Aggressive = 0.5,
		Reaction = 0.5,
		Agility = 0.5,
		ConditionWeight = (weights and weights.ConditionWeight) or 1,
		ComboWeight = (weights and weights.ComboWeight) or 1,
		Skills = skills,
		Combos = {},
	}
end

--- Набор скиллов, повторяющий раскладку бота: ближняя атака, блок, дальняя
--- атака, грaб с обязательным условием и отход.
local SKILLS = {
	Punch = {
		Priority = 0,
		Distance = 8,
		PreferredDistance = { Min = 5, Max = 8 },
		PreferredConditions = { "TARGET_SHORT_RANGE" },
		PenaltyConditions = { "TARGET_ATTACKING" },
	},
	Block = {
		PreferredConditions = { "TARGET_BLOCKABLE", "TARGET_PERFECT_BLOCKABLE" },
		ForbiddenConditions = { "TARGET_IGNORE_BLOCK" },
	},
	Barrage = {
		Distance = 10,
		PreferredConditions = { "TARGET_RAGDOLLED" },
	},
	Grab = {
		RequiredConditions = { "TARGET_BLOCKING" },
	},
	Dash = {
		PreferredConditions = { "TARGET_ATTACKING", "TARGET_IGNORE_BLOCK" },
	},
}

local ALL = candidates({ "Punch", "Block", "Barrage", "Grab", "Dash" })

local function selectBest(
	conditions: { any },
	distance: number,
	combo: string?,
	skills: any?,
	weights: any?
)
	return SkillPriority.Select(
		makeConfig(skills or SKILLS, weights),
		ALL,
		conditions,
		distance,
		combo
	)
end

-- ПУСТЫЕ СЛУЧАИ -----------------------------------------------------------

do
	equal("empty candidates: nil", SkillPriority.Select(makeConfig(SKILLS), {}, {}, 6, nil), nil)
	equal(
		"skill missing from config is skipped",
		SkillPriority.Select(makeConfig(SKILLS), candidates({ "Run" }), {}, 6, nil),
		nil
	)
end

-- ЖЁСТКИЕ ФИЛЬТРЫ ---------------------------------------------------------

do
	local config = makeConfig({ Grab = { RequiredConditions = { "TARGET_BLOCKING" } } })
	equal(
		"required: missing condition excludes the skill",
		SkillPriority.Select(config, candidates({ "Grab" }), {}, 6, nil),
		nil
	)

	local met = SkillPriority.Select(config, candidates({ "Grab" }), { "TARGET_BLOCKING" }, 6, nil)
	equal("required: met condition keeps the skill", met and met.Id, "Grab")
end

do
	local config = makeConfig({
		Block = { ForbiddenConditions = { "TARGET_IGNORE_BLOCK" } },
	})
	equal(
		"forbidden: present condition excludes the skill",
		SkillPriority.Select(config, candidates({ "Block" }), { "TARGET_IGNORE_BLOCK" }, 6, nil),
		nil
	)
end

do
	local config = makeConfig({ Punch = { Distance = 8 } })
	equal(
		"distance: beyond max excludes the skill",
		SkillPriority.Select(config, candidates({ "Punch" }), {}, 8.5, nil),
		nil
	)

	local inside = SkillPriority.Select(config, candidates({ "Punch" }), {}, 8, nil)
	equal("distance: exactly at max is still allowed", inside and inside.Id, "Punch")
end

-- МЯГКИЕ УСЛОВИЯ ----------------------------------------------------------

do
	-- Цель атакует вблизи: Punch = +1 (дистанция) -1 (атака) +1 (близко) = 1,
	-- Dash = +1 (атака) = 1, Block/Grab вне выбора, Barrage = 0.
	local result = selectBest({ "TARGET_SHORT_RANGE", "TARGET_ATTACKING" }, 6)
	equal("preferred and penalty net out", result and result.Score, 1)
	check(
		"tie is resolved to one of the tied skills",
		result ~= nil and (result.Id == "Punch" or result.Id == "Dash"),
		result and result.Id
	)
end

do
	-- Штраф не запрещает: единственный кандидат возвращается с отрицательным счётом.
	local config = makeConfig({ Punch = { PenaltyConditions = { "TARGET_ATTACKING" } } })
	local result =
		SkillPriority.Select(config, candidates({ "Punch" }), { "TARGET_ATTACKING" }, 6, nil)

	equal("penalty: skill is still selectable", result and result.Id, "Punch")
	equal("penalty: score goes below zero", result and result.Score, -1)
end

do
	-- Минус один, но полоса дистанции перекрывает штраф.
	local config = makeConfig({
		Punch = {
			Distance = 8,
			PreferredDistance = { Min = 5, Max = 8 },
			PenaltyConditions = { "TARGET_ATTACKING" },
		},
	})

	local inside =
		SkillPriority.Select(config, candidates({ "Punch" }), { "TARGET_ATTACKING" }, 6, nil)
	equal("preferred distance adds to the penalty", inside and inside.Score, 0)

	local outside =
		SkillPriority.Select(config, candidates({ "Punch" }), { "TARGET_ATTACKING" }, 4, nil)
	equal("outside the band the bonus is absent", outside and outside.Score, -1)
end

do
	local config = makeConfig({
		Block = { PreferredConditions = { "TARGET_BLOCKABLE", "TARGET_PERFECT_BLOCKABLE" } },
	})

	local one =
		SkillPriority.Select(config, candidates({ "Block" }), { "TARGET_BLOCKABLE" }, 6, nil)
	equal("preferred: one matched condition", one and one.Score, 1)

	local two = SkillPriority.Select(
		config,
		candidates({ "Block" }),
		{ "TARGET_BLOCKABLE", "TARGET_PERFECT_BLOCKABLE" },
		6,
		nil
	)
	equal("preferred: matched conditions add up", two and two.Score, 2)
end

do
	local config = makeConfig({
		Punch = {
			Distance = 8,
			PreferredDistance = { Min = 5, Max = 8 },
			PreferredConditions = { "TARGET_SHORT_RANGE" },
		},
	}, { ConditionWeight = 2 })

	local result =
		SkillPriority.Select(config, candidates({ "Punch" }), { "TARGET_SHORT_RANGE" }, 6, nil)
	equal("weight: every soft source is multiplied", result and result.Score, 4)
end

do
	-- Полоса с одной границей: Min без Max и Max без Min.
	local config = makeConfig({ Punch = { PreferredDistance = { Min = 12 } } })
	local far = SkillPriority.Select(config, candidates({ "Punch" }), {}, 20, nil)
	equal("preferred distance: open upper bound", far and far.Score, 1)

	local config2 = makeConfig({ Punch = { PreferredDistance = { Max = 6 } } })
	local near = SkillPriority.Select(config2, candidates({ "Punch" }), {}, 6, nil)
	equal("preferred distance: open lower bound", near and near.Score, 1)

	local beyond = SkillPriority.Select(config2, candidates({ "Punch" }), {}, 7, nil)
	equal("preferred distance: outside gives nothing", beyond and beyond.Score, 0)
end

-- КОМБО -------------------------------------------------------------------

do
	-- Ровно порог: без комбо побеждает ближний удар, с комбо — план.
	local open = selectBest({}, 6)
	equal("combo: plan only biases an exact tie", open and open.Id, "Punch")

	local planned = selectBest({}, 6, "Barrage")
	equal("combo: wins the tie against conditions", planned and planned.Id, "Barrage")
	equal("combo: bonus raises the planned skill", planned and planned.Score, 1)
end

do
	-- Два совпавших условия перебивают бонус плана: Block = 2, Punch = 1 (комбо),
	-- Barrage = 1 (ragdoll), причём дистанция 4 вне полосы Punch.
	local result = selectBest({
		"TARGET_BLOCKABLE",
		"TARGET_PERFECT_BLOCKABLE",
		"TARGET_RAGDOLLED",
	}, 4, "Punch")

	equal("combo: matched conditions outweigh the plan bonus", result and result.Id, "Block")
	equal("combo: winner keeps its own score", result and result.Score, 2)
end

do
	local config = makeConfig({ Punch = {}, Barrage = {} }, { ComboWeight = 5 })
	local result =
		SkillPriority.Select(config, candidates({ "Punch", "Barrage" }), {}, 6, "Barrage")

	equal("combo weight is configurable", result and result.Score, 5)
end

do
	-- Скилл из комбо выбывает по жёсткому фильтру — бонус его не спасает.
	-- Grab требует `TARGET_BLOCKING`, условий нет, план указывает на Grab.
	local result = selectBest({}, 6, "Grab")

	equal("combo: ineligible planned skill is skipped", result and result.Id, "Punch")
end

-- УДЕРЖАНИЕ ---------------------------------------------------------------

do
	local config = makeConfig({
		Block = {
			HoldWhile = { "TARGET_BLOCKABLE", "TARGET_PERFECT_BLOCKABLE" },
			HoldUntil = { "TARGET_STUNNED" },
		},
	})

	-- Цель замахивается блокируемым: держим, несмотря на то что блок проигрывает
	-- остальным по приоритету.
	local held = SkillPriority.ShouldRelease(
		config,
		"Block",
		{ "TARGET_ATTACKING", "TARGET_BLOCKABLE" },
		"Punch"
	)
	equal("hold while: keeps the block during a blockable attack", held, false)

	-- Угрозы больше нет — блок обязан отпустить, даже если лучшим кандидатом
	-- оказался скилл на кулдауне.
	local idle = SkillPriority.ShouldRelease(config, "Block", {}, nil)
	equal("hold while: releases when the attack is over", idle, true)

	-- Аварийный сброс сильнее удержания.
	local stunned = SkillPriority.ShouldRelease(
		config,
		"Block",
		{ "TARGET_BLOCKABLE", "TARGET_STUNNED" },
		"Punch"
	)
	equal("hold until: emergency abort beats hold while", stunned, true)
end

do
	-- `HoldWhile` задан, но ни одно условие не выполнено.
	local config = makeConfig({ Block = { HoldWhile = { "TARGET_BLOCKABLE" } } })
	equal(
		"hold while: a single unsatisfied condition releases",
		SkillPriority.ShouldRelease(config, "Block", { "TARGET_ATTACKING" }, "Punch"),
		true
	)
end

do
	-- Страховка пересчётом: `HoldWhile` не задан, держимся, пока скилл лучший.
	local config = makeConfig({ Block = {} })

	equal(
		"hold fallback: stays while it is the best candidate",
		SkillPriority.ShouldRelease(config, "Block", {}, "Block"),
		false
	)

	equal(
		"hold fallback: releases once another skill wins",
		SkillPriority.ShouldRelease(config, "Block", {}, "Punch"),
		true
	)

	-- Все альтернативы на кулдауне — держаться есть смысла.
	equal(
		"hold fallback: no alternatives means keep holding",
		SkillPriority.ShouldRelease(config, "Block", {}, nil),
		false
	)
end

do
	-- Скилл без настроек в конфиге удерживать незачем.
	equal(
		"hold: unknown skill releases immediately",
		SkillPriority.ShouldRelease(makeConfig(SKILLS), "Nope", {}, "Punch"),
		true
	)
end

-- БЛОК ПРОТИВ ПРОСТОИ ЦЕЛИ ------------------------------------------------

do
	-- Регрессия: блок без `HoldWhile` и без оснований держался вечно и глушил
	-- все скиллы. С `HoldWhile` он отпускается, как только цель замолчала.
	local config = makeConfig({
		Block = { HoldWhile = { "TARGET_BLOCKABLE" } },
		Punch = { Priority = 1 },
	})

	local conditions = { "TARGET_SHORT_RANGE" }
	local rival = SkillPriority.Select(config, candidates({ "Punch" }), conditions, 6, nil)
	local released = SkillPriority.ShouldRelease(config, "Block", conditions, rival and rival.Id)

	equal("idle: block is dropped as soon as nothing threatens", released, true)
	equal("idle: punch takes the slot", rival and rival.Id, "Punch")
end

do
	-- Пустой список в Luau истинно: без проверки `HoldWhile = {}` означало бы
	-- «отпускать каждый кадр», а не «удержание не настроено».
	local config = makeConfig({ Block = { HoldWhile = {} } })
	equal(
		"hold while: empty list falls back to recompute",
		SkillPriority.ShouldRelease(config, "Block", {}, "Block"),
		false
	)

	local gone = SkillPriority.ShouldRelease(config, "Block", {}, "Punch")
	equal("hold while: empty list still loses to a better skill", gone, true)
end

-- КОНФИГИ БОТОВ -----------------------------------------------------------

local CONDITION_GROUPS = {
	"RequiredConditions",
	"ForbiddenConditions",
	"PreferredConditions",
	"PenaltyConditions",
	"HoldUntil",
	"HoldWhile",
}

for _, path in CONFIG_FILES do
	local name = string.match(path, "([^/]+)%.luau$") :: string
	local config = loadModule(path)

	for skillId, options in config.Skills do
		for _, group in CONDITION_GROUPS do
			for _, condition in (options[group] or {}) do
				check(
					`{name}/{skillId}: unknown condition in {group}`,
					botCharacters.SkillConditions[condition] ~= nil,
					tostring(condition)
				)
			end
		end
	end

	--- Скилл, которого нет в `Skills`, отсекается allowlist'ом и не сработает
	--- никогда, даже если он стоит в комбо.
	for _, combo in config.Combos do
		check(`{name}: combo is not empty`, #combo > 0)

		for _, skillId in combo do
			check(
				`{name}: combo skill is described in Skills`,
				config.Skills[skillId] ~= nil,
				`{skillId} is used in a combo but has no options`
			)
		end
	end

	--- Комбо без скиллов бессмысленно: план не даст бонуса никому.
	check(`{name}: has at least one combo`, #(config.Combos or {}) > 0)

	--- Перфект-блок требует свежего нажатия Block в кадре попадания, а
	--- `Skill:Activate` выходит рано, пока скилл активен. Значит удерживать блок
	--- на парируемой атаке нельзя — иначе окно истечёт до удара. Без этой строки
	--- бот молча теряет перфект-блок, не падая нигде.
	local block = config.Skills["Block"]
	if block then
		local holdUntil = block.HoldUntil or {}
		check(
			`{name}: Block releases on perfect-blockable attacks`,
			table.find(holdUntil, "TARGET_PERFECT_BLOCKABLE") ~= nil,
			"HoldUntil must contain TARGET_PERFECT_BLOCKABLE"
		)
	end
end

-- СЛОВАРЬ ТЕГОВ -----------------------------------------------------------

--- Скиллы не грузятся в `lune` — они тянут Roblox, — поэтому теги читаются из
--- исходника. Смысл проверки не в парсере, а в том, чтобы рукописный скилл не
--- разошёлся со словарём молча: валидатор конструктора такие значения
--- отвергает, и скилл молча перестаёт работать в логике ботов.
local SKILL_FILES = {
	"src/server/skills/Punch.luau",
	"src/server/skills/Barrage.luau",
	"src/server/skills/StandBarrage.luau",
	"src/server/skills/Dash.luau",
	"src/server/skills/Block.luau",
	"src/server/skills/Grab.luau",
	"src/server/skills/Summon.luau",
	"src/server/skills/Standless/Footrest.luau",
	"src/server/skills/Standless/Uppercut.luau",
	"src/server/skills/Standless/CircularKick.luau",
	"src/server/skills/Standless/Counter.luau",
	"src/server/skills/Gerson/Bonk.luau",
	"src/server/skills/Gerson/ShellLaunch.luau",
	"src/server/skills/Undyne/ArcSpearStrike.luau",
	"src/server/skills/Undyne/WaitALittleBit.luau",
}

for _, path in SKILL_FILES do
	local skillId = string.match(path, "([^/]+)%.luau$") :: string
	local source = fs.readFile(path)

	local block = string.match(source, "SkillCharacters%s*=%s*{([^}]*)}")
	check(`{skillId}: has a SkillCharacters block`, block ~= nil, path)

	if block then
		for tag in string.gmatch(block, '"([^"]+)"') do
			check(
				`{skillId}: tag is declared in bot-characters`,
				botCharacters.SkillCharacters[tag] ~= nil,
				`"{tag}" is not in the vocabulary`
			)
		end
	end
end

-- ИТОГ --------------------------------------------------------------------

print(`[tools.tests.bot-skill-priority] passed: {passed}, failed: {#failures}`)

if #failures > 0 then error(table.concat(failures, "\n"), 0) end

return { passed = passed, failed = #failures }
