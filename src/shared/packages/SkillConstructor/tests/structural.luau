--!strict
--- Постоянные тесты `validateStructural` (§9).
---
--- Файл работает в двух средах: `lune run src/shared/packages/SkillConstructor/tests/structural.luau`
--- для CI и `require(ReplicatedStorage.shared.packages.SkillConstructor.tests.structural)`
--- в Studio. Отсюда shim на `validator` — в `lune` у теста нет `script.Parent`,
--- а в игре соседний по файловой системе модуль недоступен по относительному пути.
---
--- Каждая проверка §9 покрыта позитивным и негативным случаем: «чистый» скилл не
--- должен давать ни ошибок, ни предупреждений, а каждый код — ровно там, где нужен.
--- Отдельно проверяется, что мусор на входе не роняет валидатор: на вход приходит
--- пользовательский JSON, и падение здесь означало бы стектрейс вместо диагностики.

local validator = if game then require(script.Parent.Parent.validator) else require("../validator")

local validate = validator.validateStructural

local passed = 0
local failures: { string } = {}

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		return
	end

	table.insert(failures, if detail then `{name} — {detail}` else name)
end

local function countOf(list: { any }, code: string): number
	local total = 0
	for _, issue in list do
		if issue.Code == code then
			total += 1
		end
	end
	return total
end

local function has(list: { any }, code: string): boolean
	return countOf(list, code) > 0
end

--- Первый код из списка: удобно, когда важно конкретное сообщение, а не факт.
local function firstOf(list: { any }): any?
	return list[1]
end

local function block(
	id: string,
	blockType: string,
	properties: { [string]: any }?,
	extra: any?
): any
	local built: { [string]: any } = {
		Id = id,
		Type = blockType,
		StartFrame = 0,
		Properties = properties or {},
	}

	for key, value in (extra or {}) :: { [string]: any } do
		built[key] = value
	end
	return built
end

local function blueprint(blocks: { any }?, fields: { [string]: any }?): any
	local built: { [string]: any } = {
		Id = "TestSkill",
		DisplayName = "Test Skill",
		Cooldown = 1,
		AssetSource = "Spec",
		SkillCharacters = { "Hit" },
		AnimationSlots = {},
		SoundSlots = {},
		Blocks = blocks or {},
		Metadata = { Version = 1 },
	}

	for key, value in (fields or {}) :: { [string]: any } do
		built[key] = value
	end
	return built
end

local function run(blocks: { any }?, fields: { [string]: any }?)
	return validate(blueprint(blocks, fields))
end

-- Позитив: минимальный валидный скилл не даёт ни ошибок, ни предупреждений.
do
	local result = validate(blueprint({ block("b1", "Hitbox") }))
	check("valid blueprint has no errors", #result.errors == 0, firstOf(result.errors))
	check("valid blueprint has no warnings", #result.warnings == 0, firstOf(result.warnings))
end

-- 1. Id
do
	check("E1: bad Id", has(validate(blueprint(nil, { Id = "bad id" })).errors, "E1"))
	local missing = blueprint()
	missing.Id = nil
	check("E1: missing Id", has(validate(missing).errors, "E1"))
	check("E1: absent Id accepted", #validate(blueprint(nil, { Id = "Ok_Id_42" })).errors == 0)
end

-- 2. Cooldown
do
	check("E2: negative Cooldown", has(validate(blueprint(nil, { Cooldown = -1 })).errors, "E2"))
	check(
		"E2: non-numeric Cooldown",
		has(validate(blueprint(nil, { Cooldown = "1" })).errors, "E2")
	)
	check("E2: zero Cooldown allowed", #validate(blueprint(nil, { Cooldown = 0 })).errors == 0)
end

-- 3. AssetSource
do
	check(
		"E3: unknown AssetSource",
		has(validate(blueprint(nil, { AssetSource = "Nope" })).errors, "E3")
	)
	check("E3: Stand allowed", #validate(blueprint(nil, { AssetSource = "Stand" })).errors == 0)
end

-- 4. StartFrame
do
	local negative = block("b1", "Hitbox", nil, { StartFrame = -1 })
	local fractional = block("b1", "Hitbox", nil, { StartFrame = 1.5 })
	local textual = block("b1", "Hitbox", nil, { StartFrame = "0" })

	check("E4: negative StartFrame", has(run({ negative }).errors, "E4"))
	check("E4: fractional StartFrame", has(run({ fractional }).errors, "E4"))
	check("E4: non-numeric StartFrame", has(run({ textual }).errors, "E4"))
	check(
		"E4: integer StartFrame accepted",
		#run({ block("b1", "Wait", nil, { StartFrame = 3 }) }).errors == 0
	)
end

-- 5. EndFrame вне Repeat
do
	local inverted = block("b1", "Wait", nil, { StartFrame = 5, EndFrame = 5 })
	local smaller = block("b2", "Wait", nil, { StartFrame = 5, EndFrame = 1 })
	check("E5: EndFrame == StartFrame", has(run({ inverted }).errors, "E5"))
	check("E5: EndFrame < StartFrame", has(run({ smaller }).errors, "E5"))
	check(
		"E5: EndFrame > StartFrame accepted",
		#run({ block("b1", "Wait", nil, { StartFrame = 1, EndFrame = 5 }) }).errors == 0
	)
end

-- 6. Неизвестный тип
do
	local result = run({ block("b1", "NoSuchBlock", { Whatever = 1 }) })
	check("E6: unknown Type", has(result.errors, "E6"))
	check("E6: no E7 for unknown Type", not has(result.errors, "E7"))
	check("E6: no E8 for unknown Type", not has(result.errors, "E8"))
end

-- 7. Неизвестное свойство
do
	local result = run({ block("b1", "Hitbox", { Nope = 1 }) })
	check("E7: unknown property", has(result.errors, "E7"))
	check("E7: Property points at key", (firstOf(result.errors) :: any).Property == "Nope")
end

-- 8. Обязательные свойства
do
	local playAnimation = block("b1", "PlayAnimation")
	check("E8: required Slot missing", has(run({ playAnimation }).errors, "E8"))

	local callback = block("b2", "CustomCallback")
	check("E8: required Code missing", has(run({ callback }).errors, "E8"))

	-- Default удовлетворяет требованию: Origin обязателен, но дефолтен (§5, §2.7).
	local hitbox = block("b3", "Hitbox")
	check("E8: default satisfies required", not has(run({ hitbox }).errors, "E8"))

	local issue = firstOf(run({ playAnimation }).errors) :: any
	check("E8: BlockId reported", issue.BlockId == "b1")
	check("E8: Property reported", issue.Property == "Slot")
	check(
		"E8: Path reported",
		issue.Path[1] == "Blocks"
			and issue.Path[2] == 1
			and issue.Path[3] == "Properties"
			and issue.Path[4] == "Slot"
	)
end

-- 9. Min / Max
do
	-- `MaxTargets` больше не число, поэтому границы проверяются на `Priority`
	-- (`Min = 0, Max = 10000`) — единственном числе `ProcessAttack`, у которого шкала
	-- совпадает с диапазоном реестра и потому проверяется на обоих концах.
	local highPriority = block("b1", "ProcessAttack", { Priority = 20000 }, {
		Children = { OnSuccess = { block("c1", "Wait") } },
	})
	local negativePriority = block("b2", "ProcessAttack", { Priority = -1 }, {
		Children = { OnSuccess = { block("c1", "Wait") } },
	})

	-- `ProcessAttack` требует заполненного `OnSuccess` (E13), поэтому «в диапазоне»
	-- проверяется на блоке вместе с ребёнком — иначе тест мерил бы не диапазон, а
	-- отсутствующий слот.
	local inRange = block("b1", "ProcessAttack", { Priority = 10000 }, {
		Children = { OnSuccess = { block("c1", "Wait") } },
	})
	check("E9: in range accepted", #run({ inRange }).errors == 0)
end

-- 9a. `MaxTargets` стал перечислением: «одна цель» или «все»
do
	local function hitbox(scope: any)
		return block("b1", "Hitbox", { MaxTargets = scope })
	end

	check("MaxTargets: Nearest accepted", #run({ hitbox("Nearest") }).errors == 0)
	check("MaxTargets: All accepted", #run({ hitbox("All") }).errors == 0)

	-- E18: строковое значение не из `Options`.
	check("E18: unknown scope rejected", has(run({ hitbox("Everything") }).errors, "E18"))

	-- Прежнее числовое значение обязано ругаться, а не молча получить дефолт. Ловит
	-- E20, а не E18: тип проверяется раньше списка значений, и «число вместо строки» —
	-- более точный диагноз, чем «нет такого варианта».
	check("E20: legacy number rejected", has(run({ hitbox(4) }).errors, "E20"))
end

-- 10. Ссылка на AnimationSlot
do
	local slots = {
		{ Id = "slot1", Name = "Attack", AnimationId = "Attack1" },
	}

	check(
		"E10: known slot accepted",
		#run({ block("b1", "PlayAnimation", { Slot = "slot1" }) }, { AnimationSlots = slots }).errors
			== 0
	)
	check(
		"E10: unknown slot",
		has(
			run({ block("b1", "PlayAnimation", { Slot = "ghost" }) }, { AnimationSlots = slots }).errors,
			"E10"
		)
	)
end

-- 10b. Ссылка на SoundSlot
--
-- Отдельная группа, потому что `Slot` у звуковых блоков резолвится в другой список.
-- Если бы индекс был один, любая проверка прошла бы и по анимационному, и по
-- звуковому слоту — то есть ошибка была бы не найдена вовсе, а не выбрана неверно.
do
	local anim = { { Id = "anim1", Name = "Attack", AnimationId = "Attack1" } }
	local sound = { { Id = "snd1", Name = "Hit", SoundId = "Hit1" } }

	check(
		"sound E10: known sound slot accepted",
		#run({ block("b1", "PlaySound", { Slot = "snd1" }) }, { SoundSlots = sound }).errors == 0
	)
	check(
		"sound E10: unknown sound slot",
		has(
			run({ block("b1", "PlaySound", { Slot = "ghost" }) }, { SoundSlots = sound }).errors,
			"E10"
		)
	)

	-- Звуковой блок не должен принимать анимационный слот: имена совпадают по форме, но
	-- указывают на разные таблицы ассетов.
	check(
		"sound E10: animation slot rejected on a sound block",
		has(
			run({ block("b1", "PlaySound", { Slot = "anim1" }) }, {
				AnimationSlots = anim,
				SoundSlots = sound,
			}).errors,
			"E10"
		)
	)

	-- И наоборот: анимационный блок не должен принимать звуковой слот.
	check(
		"sound E10: sound slot rejected on an animation block",
		has(
			run({ block("b1", "PlayAnimation", { Slot = "snd1" }) }, {
				AnimationSlots = anim,
				SoundSlots = sound,
			}).errors,
			"E10"
		)
	)

	check(
		"sound E10: StopSound resolves against SoundSlots",
		#run({ block("b1", "StopSound", { Slot = "snd1" }) }, { SoundSlots = sound }).errors == 0
	)
end

-- 10c. Ровно одно из `Slot` и `Sound`
--
-- `PlaySound` получил `Slot` как замену прямой ссылки, но старые файлы версии 1
-- присылают `Sound`, поэтому оба поля объявлены опциональными. Оба заполнены — не
-- «победил кто первый», а ошибка: полученный ассет зависел бы от порядка чтения.
do
	local sound = { { Id = "snd1", Name = "Hit", SoundId = "Hit1" } }

	check(
		"sound: both Slot and Sound rejected",
		has(
			run(
				{ block("b1", "PlaySound", { Slot = "snd1", Sound = "Hit1" }) },
				{ SoundSlots = sound }
			).errors,
			"E2"
		)
	)
	check(
		"sound: legacy Sound alone still accepted",
		#run({ block("b1", "PlaySound", { Sound = "Hit1" }) }, { SoundSlots = sound }).errors == 0
	)
	check(
		"sound: Slot alone accepted",
		#run({ block("b1", "PlaySound", { Slot = "snd1" }) }, { SoundSlots = sound }).errors == 0
	)
	check(
		"sound: StopSound with both rejected",
		has(
			run(
				{ block("b1", "StopSound", { Slot = "snd1", Sound = "Hit1" }) },
				{ SoundSlots = sound }
			).errors,
			"E2"
		)
	)

	-- Ни одного — тоже ошибка. Блок без звука не значит ничего, и заметить это можно
	-- было бы только по скиллу, который молчит.
	check(
		"sound: PlaySound with neither is reported",
		has(run({ block("b1", "PlaySound") }, { SoundSlots = sound }).errors, "E8")
	)
	check(
		"sound: StopSound with neither is reported",
		has(run({ block("b1", "StopSound") }, { SoundSlots = sound }).errors, "E8")
	)

	-- Старый путь не должен попадать под E8: `StopSound` в версии 1 не существовало, и
	-- требование `Slot` запретило бы ровно тот файл, который эмиттер печатает.
	check(
		"sound: StopSound legacy Sound alone still accepted",
		#run({ block("b1", "StopSound", { Sound = "Hit1" }) }, { SoundSlots = sound }).errors == 0
	)
end

-- 10d. `Duration`
--
-- Нижняя граница, а не потолок: эмиттер берёт `max(60, Duration, последний занятый кадр)`,
-- поэтому значение меньше дерева просто игнорируется. Проверять надо только тип и знак —
-- «должно быть длиннее дерева» было бы ошибкой в правиле, а не в данных.
do
	check("Duration: absent accepted", #run({ block("b1", "Hitbox") }).errors == 0)
	check("Duration: zero accepted", #run(nil, { Duration = 0 }).errors == 0)
	check("Duration: positive accepted", #run(nil, { Duration = 240 }).errors == 0)
	check("Duration: negative rejected", has(run(nil, { Duration = -1 }).errors, "E2"))
	check("Duration: non-numeric rejected", has(run(nil, { Duration = "120" }).errors, "E2"))

	-- Ниже последнего шага — не ошибка, а ровно то, что `Duration` и означает.
	local short = { block("b1", "Hitbox", 600) }
	check(
		"Duration: shorter than the tree is not an error",
		#run(short, { Duration = 30 }).errors == 0
	)
end

-- 10e. `AttackInfoDefaults`
do
	check("AttackInfoDefaults: absent accepted", #run({ block("b1", "Hitbox") }).errors == 0)
	check("AttackInfoDefaults: table accepted", #run(nil, { AttackInfoDefaults = {} }).errors == 0)
	check(
		"AttackInfoDefaults: dotted keys accepted",
		#run(nil, { AttackInfoDefaults = { Damage = 10, ["Stun.Duration"] = 1.5 } }).errors == 0
	)

	-- Не-таблица: `isPrintable` в эмиттере такие значения отбрасывает, то есть секция
	-- молча исчезла бы из шапки скилла. Тип проверяется здесь, а не там.
	check(
		"AttackInfoDefaults: number rejected",
		has(run(nil, { AttackInfoDefaults = 5 }).errors, "E2")
	)
	check(
		"AttackInfoDefaults: string rejected",
		has(run(nil, { AttackInfoDefaults = "x" }).errors, "E2")
	)
	check(
		"AttackInfoDefaults: true rejected",
		has(run(nil, { AttackInfoDefaults = true }).errors, "E2")
	)
end

-- 11. Вложенность запрещена
do
	local hitboxWithChild = block("b1", "Hitbox", nil, {
		Children = { Body = { block("c1", "Wait") } },
	})

	local result = run({ hitboxWithChild })
	check("E11: nesting rejected", has(result.errors, "E11"))
	check("E11: E12 not reported instead", not has(result.errors, "E12"))
end

-- 12. Неизвестный слот
do
	local attack = block("b1", "ProcessAttack", nil, {
		Children = {
			Nope = { block("c1", "Wait") },
			OnSuccess = { block("c2", "Wait") },
		},
	})

	local result = run({ attack })
	check("E12: unknown slot", has(result.errors, "E12"))
	check("E12: E13 satisfied", not has(result.errors, "E13"))
end

-- 13. RequiredSlots
do
	local noReactions = block("b1", "ProcessAttack", nil, {
		Children = { OnBlocked = { block("c1", "Wait") } },
	})

	local result = run({ noReactions })
	check("E13: unfilled required slot", has(result.errors, "E13"))
	check("E13: filled required slot accepted", #run({
		block("b1", "ProcessAttack", nil, {
			Children = { OnSuccess = { block("c1", "Wait") } },
		}),
	}).errors == 0)
end

-- 14. Repeat
do
	local empty = run({ block("r1", "Repeat", nil, { EndFrame = 10 }) })
	check("E14: Repeat without body", has(empty.errors, "E14"))
	check("E14: single issue for empty Repeat", countOf(empty.errors, "E14") == 1)
	check("E14: no duplicate from E13", not has(empty.errors, "E13"))
	check("E14: no duplicate from E5", not has(empty.errors, "E5"))

	local inverted = run({
		block(
			"r1",
			"Repeat",
			nil,
			{ StartFrame = 5, EndFrame = 5, Children = { Body = { block("c1", "Wait") } } }
		),
	})
	check("E14: Repeat with EndFrame <= StartFrame", has(inverted.errors, "E14"))
	check("E14: single issue for inverted Repeat", countOf(inverted.errors, "E14") == 1)

	local both = run({ block("r1", "Repeat", nil, { StartFrame = 5, EndFrame = 5 }) })
	local issue = firstOf(both.errors) :: any
	check("E14: aggregated message mentions body", tostring(issue.Message):find("no body") ~= nil)
	check(
		"E14: aggregated message mentions range",
		tostring(issue.Message):find("EndFrame must be greater") ~= nil
	)

	check("E14: valid Repeat accepted", #run({
		block("r1", "Repeat", nil, {
			StartFrame = 0,
			EndFrame = 10,
			Children = { Body = { block("c1", "Wait") } },
		}),
	}).errors == 0)
end

-- 15 / 16. Branch и CustomCallback
do
	local branch = block("b1", "Branch", { Condition = "   " })
	local callback = block("b2", "CustomCallback", { Code = "" })
	check("E15: empty condition", has(run({ branch }).errors, "E15"))
	check("E16: empty code", has(run({ callback }).errors, "E16"))
	check(
		"E15: non-empty condition accepted",
		#run({ block("b1", "Branch", { Condition = "seq.Ctx.Hit" }) }).errors == 0
	)
end

-- 17. SetNoCollision
do
	check(
		"E17: State=false",
		has(run({ block("b1", "SetNoCollision", { State = false }) }).errors, "E17")
	)
	check(
		"E17: State=true accepted",
		#run({ block("b1", "SetNoCollision", { State = true }) }).errors == 0
	)
end

-- 18. Значения из Options (общая проверка для всех enum)
do
	check(
		"E18: unknown IFrames level",
		has(run({ block("b1", "SetIFrames", { Level = "Nope" }) }).errors, "E18")
	)
	check(
		"E18: unknown Stun priority",
		has(
			run({
				block("b1", "ProcessAttack", { ["Stun.Priority"] = "Nope" }, {
					Children = { OnSuccess = { block("c1", "Wait") } },
				}),
			}).errors,
			"E18"
		)
	)
	check(
		"E18: known level accepted",
		#run({ block("b1", "SetIFrames", { Level = "Grab" }) }).errors == 0
	)
end

-- 19. CreateGrab BindMode
do
	local grabbed = block("b1", "CreateGrab", { BindMode = "RootToRoot" })
	check("E19: RootToRoot without Offset", has(run({ grabbed }).errors, "E19"))

	local withOffset = block("b2", "CreateGrab", {
		BindMode = "RootToRoot",
		Offset = { ["$"] = "CF", px = 0, py = 0, pz = -4, rx = 0, ry = 0, rz = 0 },
	})
	check("E19: RootToRoot with Offset", not has(run({ withOffset }).errors, "E19"))
	check(
		"E19: BindMode=None without Offset",
		not has(run({ block("b3", "CreateGrab", { BindMode = "None" }) }).errors, "E19")
	)
end

-- 20. Тип значения
do
	check(
		"E20: string for Vector3",
		has(run({ block("b1", "Hitbox", { Size = "big" }) }).errors, "E20")
	)
	check(
		"E20: number for CFrame",
		has(run({ block("b1", "Hitbox", { Origin = 3 }) }).errors, "E20")
	)
	check(
		"E20: string for boolean",
		has(run({ block("b1", "SetArmor", { State = "yes" }) }).errors, "E20")
	)

	local issue = firstOf(run({ block("b1", "SetArmor", { State = "yes" }) }).errors) :: any
	check("E20: type named in message", tostring(issue.Message):find("boolean") ~= nil)

	-- `Size` объявлен как `Vector3 or number`, и tagged-таблица после `codec.decode`
	-- тоже принимается — обе формы валидны (§8).
	check("E20: tagged Vector3 accepted", not has(
		run({
			block("b1", "Hitbox", { Size = { ["$"] = "V3", x = 7, y = 7, z = 7 } }),
		}).errors,
		"E20"
	))
	check(
		"E20: numeric Size accepted",
		not has(run({ block("b1", "Hitbox", { Size = 5 }) }).errors, "E20")
	)
	check("E20: unknown type not reported", not has(run({ block("b1", "Wait") }).errors, "E20"))
end
-- 28. Форма хитбокса против типа `Size`
--
-- `CombatService:Hitbox` различает формы по типу `Size`: `number` — радиус и
-- `GetPartBoundsInRadius`, `Vector3` — `GetPartBoundsInBox`. Объединение типов в
-- реестре принимает оба, поэтому несоответствие объявленной формы не является
-- «неправильным типом» — оно не является ошибкой вообще, пока не сказать об этом
-- явно. Без E28 скилл с `Shape = "Ball"` и векторным `Size` тихо получался кубом,
-- и ни интерфейс, ни генератор об этом не говорили.
do
	check(
		"E28: Ball with a numeric Size is fine",
		not has(run({ block("b1", "Hitbox", { Shape = "Ball", Size = 5 }) }).errors, "E28")
	)
	check(
		"E28: Box with a Vector3 Size is fine",
		not has(
			run({
				block(
					"b1",
					"Hitbox",
					{ Shape = "Box", Size = { ["$"] = "V3", x = 7, y = 7, z = 7 } }
				),
			}).errors,
			"E28"
		)
	)
	check(
		"E28: absent Shape keeps the old behaviour",
		not has(run({ block("b1", "Hitbox", { Size = 5 }) }).errors, "E28")
	)
	check(
		"E28: absent Shape accepts a Vector3 too",
		not has(
			run({ block("b1", "Hitbox", { Size = { ["$"] = "V3", x = 7, y = 7, z = 7 } }) }).errors,
			"E28"
		)
	)

	check(
		"E28: Ball with a Vector3 Size is rejected",
		has(
			run({
				block(
					"b1",
					"Hitbox",
					{ Shape = "Ball", Size = { ["$"] = "V3", x = 7, y = 7, z = 7 } }
				),
			}).errors,
			"E28"
		)
	)
	check(
		"E28: Box with a numeric Size is rejected",
		has(run({ block("b1", "Hitbox", { Shape = "Box", Size = 5 }) }).errors, "E28")
	)

	-- Сообщение обязано называть обе стороны: иначе непонятно, что именно исправлять —
	-- форму или размер.
	local mentions = false
	for _, entry in
		run({
			block("b1", "Hitbox", { Shape = "Ball", Size = { ["$"] = "V3", x = 7, y = 7, z = 7 } }),
		}).errors
	do
		if entry.Code == "E28" and string.find(entry.Message, "Ball", 1, true) then
			mentions = true
			break
		end
	end
	check("E28: names the shape", mentions)
end

-- W1. ProcessAttack внутри Repeat
do
	local attackInLoop = block("r1", "Repeat", nil, {
		StartFrame = 0,
		EndFrame = 5,
		Children = {
			Body = {
				block(
					"c1",
					"ProcessAttack",
					nil,
					{ Children = { OnSuccess = { block("c2", "Wait") } } }
				),
			},
		},
	})

	check("W1: ProcessAttack inside Repeat", has(run({ attackInLoop }).warnings, "W1"))
	check("W1: not an error", not has(run({ attackInLoop }).errors, "W1"))
end

-- 24. Вложенный `Repeat` запрещён
--
-- Раньше это было предупреждением W2 про «диапазон сливается с внешним». Но дело не в
-- слиянии: эмиттер делал много-кадровым весь верхнеуровневый блок, внутри которого
-- нашёлся `Repeat`, а `Sequencer` исполняет такой элемент на каждом кадре. То есть
-- `ProcessAttack` с `Repeat` в `OnSuccess` бил цель один раз на КАДР, и ни одно
-- предупреждение об этом не говорило. Теперь это ошибка, а `W2` упразднён как
-- недостижимый: вложенный `Repeat` всё равно сначала ловит E24.
do
	local nestedInRepeat = block("r1", "Repeat", nil, {
		StartFrame = 0,
		EndFrame = 10,
		Children = {
			Body = {
				block("r2", "Repeat", nil, {
					StartFrame = 2,
					EndFrame = 5,
					Children = { Body = { block("c1", "Wait") } },
				}),
			},
		},
	})

	check("E24: Repeat inside Repeat", has(run({ nestedInRepeat }).errors, "E24"))

	local nestedInAttack = block("a1", "ProcessAttack", nil, {
		Children = {
			OnSuccess = {
				block("r2", "Repeat", nil, {
					StartFrame = 2,
					EndFrame = 5,
					Children = { Body = { block("c1", "Wait") } },
				}),
			},
		},
	})

	check("E24: Repeat inside ProcessAttack", has(run({ nestedInAttack }).errors, "E24"))

	-- Сообщение обязано называть контейнер: иначе в дереве на двадцать блоков непонятно,
	-- к чему относится претензия, а путь до узла пользователю ещё и искать.
	local mentionsParent = false
	for _, entry in run({ nestedInAttack }).errors do
		if entry.Code == "E24" and string.find(entry.Message, "ProcessAttack", 1, true) then
			mentionsParent = true
			break
		end
	end
	check("E24: names the parent container", mentionsParent)

	-- Верхний `Repeat` — ровно то, для чего он и сделан, и на E24 не попадает.
	local topLevel = block("r1", "Repeat", nil, {
		StartFrame = 0,
		EndFrame = 10,
		Children = { Body = { block("c1", "Wait") } },
	})

	check("E24: a top-level Repeat is fine", not has(run({ topLevel }).errors, "E24"))
	check("E24: W2 is gone", not has(run({ nestedInRepeat }).warnings, "W2"))
end

-- W3. Branch внутри ProcessAttack
do
	local branchInAttack = block("b1", "ProcessAttack", nil, {
		Children = {
			OnSuccess = { block("c1", "Branch", { Condition = "true" }) },
		},
	})

	local result = run({ branchInAttack })
	check("W3: Branch inside ProcessAttack", has(result.warnings, "W3"))
	check(
		"W3: not reported for top-level Branch",
		not has(run({ block("x", "Branch", { Condition = "true" }) }).warnings, "W3")
	)
end

-- W4. Широкий Repeat
do
	local wide = block("r1", "Repeat", nil, {
		StartFrame = 0,
		EndFrame = 31,
		Children = { Body = { block("c1", "Wait") } },
	})

	check("W4: wider than 30 frames", has(run({ wide }).warnings, "W4"))
	check("W4: exactly 30 frames accepted", not has(
		run({
			block("r1", "Repeat", nil, {
				StartFrame = 0,
				EndFrame = 30,
				Children = { Body = { block("c1", "Wait") } },
			}),
		}).warnings,
		"W4"
	))
end

-- W5. Сырой Luau
do
	local branch = block("b1", "Branch", { Condition = "true" })
	local callback = block("b2", "CustomCallback", { Code = "print(1)" })
	check("W5: raw condition", has(run({ branch }).warnings, "W5"))
	check("W5: raw callback", has(run({ callback }).warnings, "W5"))
end

-- W6. ProcessAttack без Block
do
	local implicit = block("b1", "ProcessAttack", nil, {
		Children = { OnSuccess = { block("c1", "Wait") } },
	})
	check("W6: hidden Block default", has(run({ implicit }).warnings, "W6"))

	local explicit = block("b2", "ProcessAttack", { ["Block.Blockable"] = true }, {
		Children = { OnSuccess = { block("c1", "Wait") } },
	})
	check("W6: explicit Block accepted", not has(run({ explicit }).warnings, "W6"))
end

-- Вложенные секции свойств: JSON-форма (§8) отдаёт `Stun = { Duration = ... }`,
-- а реестр знает `Stun.Duration`. Обе формы обязаны валидироваться одинаково.
do
	local nested =
		block("b1", "ProcessAttack", nil, { Children = { OnSuccess = { block("c1", "Wait") } } })
	nested.Properties = {
		Damage = 15,
		Stun = { Duration = 0.7, Priority = "Heavy" },
		Block = { Blockable = true, PerfectBlockable = false },
	}

	local result = run({ nested })
	check("nested groups: accepted", #result.errors == 0, firstOf(result.errors))
	check("nested groups: no W6", not has(result.warnings, "W6"))

	local flat = run({
		block(
			"b2",
			"ProcessAttack",
			{ Damage = 15, ["Stun.Duration"] = 0.7, ["Stun.Priority"] = "Heavy" },
			{ Children = { OnSuccess = { block("c1", "Wait") } } }
		),
	})
	check("nested groups: flat twin accepted", #flat.errors == 0, firstOf(flat.errors))

	local unknown = run({
		block("b3", "ProcessAttack", { Stun = { Nope = 1 } }, {
			Children = { OnSuccess = { block("c1", "Wait") } },
		}),
	})
	check("nested groups: unknown leaf is E7", has(unknown.errors, "E7"), firstOf(unknown.errors))

	local wrongType = run({
		block("b4", "ProcessAttack", { Stun = { Duration = "long" } }, {
			Children = { OnSuccess = { block("c1", "Wait") } },
		}),
	})
	check(
		"nested groups: wrong leaf type is E20",
		has(wrongType.errors, "E20"),
		firstOf(wrongType.errors)
	)

	-- Помеченное значение остаётся значением: тег не даёт развернуть CFrame в секцию.
	local tagged = run({
		block(
			"b5",
			"Hitbox",
			{ Origin = { ["$"] = "CF", px = 0, py = 0, pz = 0, rx = 0, ry = 0, rz = 0 } }
		),
	})
	check("nested groups: tagged value kept as leaf", #tagged.errors == 0, firstOf(tagged.errors))
end
-- Мусор на входе: валидатор обязан отвечать, а не падать
do
	local notATable = validate(nil)
	check("garbage: nil blueprint", has(notATable.errors, "E1"))

	local asString = validate("nope")
	check("garbage: string blueprint", has(asString.errors, "E1"))

	local badBlocks = validate(blueprint({ "nope", 5, {}, block("ok", "Wait") }))
	check("garbage: Blocks as string", #validate(blueprint(nil, { Blocks = "oops" })).errors >= 0)
	check("garbage: non-table blocks skipped", has(badBlocks.errors, "E6"))
	check("garbage: sibling block still validated", not has(badBlocks.errors, "E7"))

	local brokenProperties = run({ block("b1", "Hitbox", "not a table") })
	check("garbage: Properties as string", not has(brokenProperties.errors, "E7"))

	local brokenChildren = run({
		block("b1", "ProcessAttack", nil, { Children = { OnSuccess = "not a table" } }),
	})
	check("garbage: slot as string", has(brokenChildren.errors, "E13"))

	local brokenSlots = run({
		block(
			"b1",
			"Repeat",
			nil,
			{ StartFrame = 0, EndFrame = 2, Children = { Body = "not a table" } }
		),
	})
	check("garbage: Repeat body as string", has(brokenSlots.errors, "E14"))
end

print(`[SkillConstructor.tests.structural] passed: {passed}, failed: {#failures}`)

if #failures > 0 then error(table.concat(failures, "\n"), 0) end

return { passed = passed, failed = #failures }
