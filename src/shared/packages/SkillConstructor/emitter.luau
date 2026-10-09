--!strict

--- Генератор модуля скилла: blueprint в JSON-форме → исходник Luau и превью кадров
--- (docs/SKILL_CONSTRUCTOR_TASK.md, §7, §10).
---
--- Модуль намеренно не требует `registry`: все блоки описаны здесь же, а форма
--- свойств приходит из `codec.encode`. Так эмиттер остаётся единственным местом,
--- где известно, во что превращается каждое свойство, а `registry` может свободно
--- меняться вместе с UI.
---
--- Границы:
---
--- * На вход — ровно то, что вернул `codec.encode`: группы свойств вложенными
---   таблицами (`Properties.Stun.Duration`), Roblox-типы в виде type-tag.
---   Roblox-глобалы при загрузке не используются, поэтому модуль грузится и в UI,
---   и в CLI на `lune` (§3).
--- * Roblox-типы не конструируются: значения печатаются вызовами `Vector3.new`,
---   `CFrame.new`, `Color3.fromRGB` прямо в текст, поэтому результат не зависит от
---   того, где выполняется генерация.
--- * Ошибки не бросаются исключением: `emit` возвращает `{ Source, Preview, Errors }`,
---   и UI печатает `Errors` пользователю. `Source` при этом остаётся разбираемым
---   Luau: сломанный блок выбрасывается, остальные печатаются как обычно.
---
--- Список `require` и локальные `Anims` / `Sounds` / `Models` выводятся по факту
--- использования (§10): пустой скилл не тянет `Enums`, а blueprint без `CreateGrab`
--- не тянет лишних зависимостей.

local codec = if game then require(script.Parent.codec) else require("./codec")

--- Нижняя граница длительности sequence. `Wait` без других блоков не должен обрезать
--- скилл до одного кадра, а меньше секунды он всё равно бессмыслен (§7, пункт 6).
local MIN_FRAMES = 60

--- Условия слотов `ProcessAttack` статичны: они известны на этапе генерации, поэтому
--- пустые слоты просто не эмитятся. Порядок совпадает с `registry.ATTACK_SLOTS`.
local ATTACK_SLOTS = {
	{ "OnSuccess", "Data.State.Success and Data.State.Continue" },
	{ "OnBlocked", "Data.State.Blocked" },
	{ "OnBlockBroken", "Data.State.Blocked and Data.State.BlockBroken" },
	{ "OnBlockCanceled", "Data.State.BlockCanceled" },
	{ "OnPerfectBlocked", "Data.State.PerfectBlocked" },
	{ "OnArmored", "Data.State.Armored" },
	{ "OnRagdolled", "Data.State.Ragdolled" },
}

--- Группы `AttackInfo` в порядке печати. Поля, которых нет в `Properties`, пропускаются
--- вместе с пустой группой — поэтому частичная секция `Block` работает (§2.7).
local INFO_GROUPS = {
	{ "Stun", { "Duration", "Priority" } },
	{ "Block", { "Blockable", "PerfectBlockable", "BlockBreak", "BlockCancel", "BlockIgnore" } },
	{
		"Knockback",
		{
			"RelativePart",
			"RelativeTowards",
			"LookVector",
			"Origin",
			"ToFront",
			"Speed",
			"Duration",
			"Velocity",
			"MaxForce",
		},
	},
	{ "Angular", { "Velocity", "Speed", "Duration", "MaxTorque" } },
	{ "Ragdoll", { "Duration" } },
}

--- Имена параметров персонажа для блоков категории `State`. Ключ — `Type` блока.
--- Имя параметра `Character` и имя свойства блока, по которому берётся значение.
---
--- Два имени в одной записи намеренно: `registry` эмиттер не требует (ему нужен `lune`),
--- поэтому раньше имя свойства вычислялось отдельно и разошлось с реестром — четыре
--- блока объявляют `State`, а эмиттер спрашивал `Value`, из-за чего `SetArmor`,
--- `SetRagdoll` и `SetRestrain` молча не эмитились вовсе. Рядом с именем параметра
--- сверять его с `registry.luau` можно глазами, и новое свойство нельзя будет забыть.
local STATE_PARAMETERS = {
	SetIFrames = { parameter = "IFrames", field = "Level" },
	SetDamageMultiplier = { parameter = "DamageMultiplier", field = "Value" },
	SetDamageReceivalMultiplier = { parameter = "DamageReceivalMultiplier", field = "Value" },
	SetMaxWalkSpeed = { parameter = "MaxWalkSpeed", field = "Value" },
	SetMinWalkSpeed = { parameter = "MinWalkSpeed", field = "Value" },
	SetMaxJumpPower = { parameter = "MaxJumpPower", field = "Value" },
	SetArmor = { parameter = "Armor", field = "State" },
	SetRagdoll = { parameter = "Ragdoll", field = "State" },
	SetNoCollision = { parameter = "NoCollision", field = "State" },
	SetRestrain = { parameter = "Restrain", field = "State" },
}

--- `SetNoCollision` принимает только `true`: `Watchers.luau:68` схлопывает `false` в
--- `true`, поэтому валидатор отклоняет `false` (§2.8), а незаполненное поле равно `true`.
local NO_COLLISION_FALLBACK = true

--- Слоты контейнеров. Пустой список означает «вложенность запрещена», и пустые слоты
--- (`Branch` без `False`, `ProcessAttack` без `OnBlocked`) не печатаются (§9 проверка 13).
local CONTAINER_SLOTS = {
	ProcessAttack = {
		"OnSuccess",
		"OnBlocked",
		"OnBlockBroken",
		"OnBlockCanceled",
		"OnPerfectBlocked",
		"OnArmored",
		"OnRagdolled",
	},
	Repeat = { "Body" },
	Branch = { "True", "False" },
}

--- Блоки, которым нужна цель в области видимости. `CreateGrab` требует жертву всегда,
--- `EmitParticle` и `EmitFolder` — только при `Origin = "Target"` (§7, §9 проверка 17).
local TARGET_ORIGIN = {
	EmitParticle = true,
	EmitFolder = true,
}

-- ИНСТРУМЕНТЫ ВЫВОДА ---------------------------------------------------------

--- Строки с отступом в `level` табов. Пустые строки отступ не получают, иначе они
--- перестают быть пустыми ни для stylua, ни для глаза.
local function indented(lines: { string }, level: number): { string }
	local result: { string } = {}
	local pad = string.rep("\t", level)

	for _, line in lines do
		table.insert(result, if line == "" then "" else pad .. line)
	end

	return result
end

local function extend(target: { string }, source: { string }): { string }
	for _, line in source do
		table.insert(target, line)
	end

	return target
end

--- Склейка списков строк в один. Принимает массив списков, а не varargs: так
--- опечатка в склейке не превращается в тихую потерю блока.
local function concat(parts: { { string } }): { string }
	local result: { string } = {}

	for _, part in parts do
		extend(result, part)
	end

	return result
end

--- Число в исходнике без мусорных нулей: `3`, а не `3.0`, и без потери точности на
--- дробных шагах из реестра (`0.05`).
local function num(value: number): string
	if value ~= value or value == math.huge or value == -math.huge then return "0" end
	if value == math.floor(value) and math.abs(value) < 1e15 then
		return string.format("%d", value)
	end
	return string.format("%.10g", value)
end

local function quoted(value: string): string
	return string.format("%q", value)
end

--- `CFrame` без поворота печатается одним конструктором: `fromEulerAnglesYXZ(0, 0, 0)` —
--- это умножение на единицу, которое только засоряет вывод.
local function cframeLiteral(value: any): string
	local base = `CFrame.new({num(value.px or 0)}, {num(value.py or 0)}, {num(value.pz or 0)})`
	local rx, ry, rz = value.rx or 0, value.ry or 0, value.rz or 0

	if rx == 0 and ry == 0 and rz == 0 then return base end
	return `{base} * CFrame.fromEulerAnglesYXZ({num(rx)}, {num(ry)}, {num(rz)})`
end

local function isIdentityCFrame(value: any): boolean
	if type(value) ~= "table" then return true end

	local rx, ry, rz = value.rx or 0, value.ry or 0, value.rz or 0
	return (value.px or 0) == 0
		and (value.py or 0) == 0
		and (value.pz or 0) == 0
		and rx == 0
		and ry == 0
		and rz == 0
end

--- Любое значение свойства в виде исходника. Строка обязательно в кавычках, иначе
--- имя ассета превратилось бы в идентификатор.
local function literal(value: any): string
	if type(value) == "string" then return quoted(value) end
	if type(value) == "table" and value["$"] == "CF" then return cframeLiteral(value) end
	return codec.toLiteral(value)
end

--- Значения, которые эмиттер умеет напечатать. Всё остальное — ошибка данных:
--- валидатор ловит её раньше (§9 проверка 20), но эмиттер обязан пережить её без
--- падения, иначе вместо сообщения пользователь получит ошибку скрипта.
local function isPrintable(value: any): boolean
	local valueType = type(value)

	if valueType == "number" or valueType == "boolean" or valueType == "string" then
		return true
	elseif valueType == "table" then
		local tag = value["$"]
		return tag == "V3" or tag == "CF" or tag == "C3"
	end

	return false
end

-- СОСТОЯНИЕ ГЕНЕРАЦИИ -------------------------------------------------------

--- Локальные переменные, которые могут понадобиться сгенерированному модулю.
--- Заполняется по ходу обхода дерева, читается при сборке шапки.
type Usage = {
	Anims: boolean,
	Sounds: boolean,
	Models: boolean,
	Enums: boolean,
	Stand: boolean,
	Players: boolean,
	Uuid: boolean,
	VFXService: boolean,
}

--- Состояние одной генерации: ошибки, счётчики имён, слоты анимаций и накопленная
--- форма `AttackInfo` для шапки модуля.
type Ctx = {
	errors: { any },
	usage: Usage,
	counters: { [string]: number },
	slots: { [string]: string },
	slotSpeed: { [string]: number },
	slotFade: { [string]: number },
	--- Звуковые слоты: та же карта «логальный GUID → ключ ассета», что и `slots`.
	soundSlots: { [string]: string },
	attackInfo: { [string]: any },
	--- Сколько в дереве блоков, создающих именованную `Buttler`-ручку, по типу.
	---
	--- Нужно блокам-отменителям: `RemoveArmor` не знает, какой из `AddArmor` в дереве
	--- к нему относится, а слот назван по порядковому номеру. Считается заранее, до
	--- эмиссии, потому что отменитель может оказаться раньше создателей в порядке
	--- обхода — и тогда он всё равно должен знать, какие имена существуют.
	handles: { [string]: number },
}

--- Что уже есть в области видимости у блока: `Target` — эмиттер уже обернул блок в
--- цикл по целям, `Data` — блок лежит внутри `andThen` от `Attack`.
type Scope = {
	Target: boolean,
	Data: boolean,
}

--- Один элемент массива `Frames`: обратная сторона сгенерированной конструкции.
--- Держится отдельно от текста, потому что по нему же собирается `Preview` (§10).
type Entry = {
	Frame: number,
	Kind: "Single" | "Range" | "Terminator",
	EndFrame: number?,
	Body: { string },
	Blocks: { any },
	--- Блок ничего не напечатал: `Wait` или сломанный блок. В `Frames` такой элемент
	--- не попадает, но в `Preview` остаётся — иначе пользователь не увидит, куда он
	--- поставил маркер.
	Empty: boolean,
	--- Порядок сортировки: `table.sort` не стабильный, а порядок кадров внутри одного
	--- тика менять нельзя.
	Order: number,
}

local function report(
	ctx: Ctx,
	code: string,
	message: string,
	path: { string | number },
	blockId: string?,
	property: string?
)
	table.insert(ctx.errors, {
		Code = code,
		Message = message,
		Path = path,
		BlockId = blockId,
		Property = property,
	})
end

local function use(ctx: Ctx, flag: keyof<Usage>)
	(ctx.usage :: any)[flag] = true
end

--- Имена локалей нумеруются: два `Hitbox` в одном callback иначе объявили бы `Targets`
--- дважды и сломали разбор модуля. Счётчик сквозной по модулю, поэтому чтение
--- получается тем же, что и в §7: `Hitbox_1`, `Hitbox_2`.
local function localName(ctx: Ctx, base: string): string
	local count = (ctx.counters[base] or 0) + 1
	ctx.counters[base] = count
	return `{base}{count}`
end

local function propertyOf(block: any, name: string): (any, boolean)
	if type(block) ~= "table" then return nil end

	local properties = block.Properties
	if type(properties) ~= "table" then return nil end

	if properties[name] ~= nil then return properties[name] end

	--- JSON-форма (§8) хранит группы вложенными таблицами, поэтому `Stun.Duration`
	--- из реестра означает `Properties.Stun.Duration`. Плоский ключ с точкой тоже
	--- принимается: файлы, правленные руками, остаются читаемыми.
	local node = properties
	local from = 1

	while true do
		local dot = string.find(name, ".", from, true)
		local key = if dot then string.sub(name, from, dot - 1) else string.sub(name, from)

		if type(node) ~= "table" then return nil, true end
		node = node[key]
		if node == nil then return nil end
		if dot == nil then break end

		from = dot + 1
	end

	return node
end

--- Путь до конкретного свойства для сообщения: `{ "Blocks", 2, "Properties", "Size" }`.
local function propertyPath(path: { string | number }, name: string): { string | number }
	local result = table.clone(path) :: { string | number }
	table.insert(result, "Properties")
	table.insert(result, name)
	return result
end

--- Значение свойства с проверкой печатаемости: отсутствующее и непечатаемое дают
--- `nil` и ошибку, эмиттер при этом продолжает собирать модуль.
local function valueOf(ctx: Ctx, block: any, name: string, path: { string | number }): any
	local value, broken = propertyOf(block, name)

	if broken then
		report(
			ctx,
			"EMIT_VALUE",
			`{name} of {tostring(block.Type)} is not a group of properties`,
			propertyPath(path, name),
			block.Id,
			name
		)
		return nil
	end

	if value == nil then return nil end

	if not isPrintable(value) then
		report(
			ctx,
			"EMIT_VALUE",
			`{name} of {tostring(block.Type)} cannot be written as Luau`,
			propertyPath(path, name),
			block.Id,
			name
		)
		return nil
	end

	return value
end

--- Enum хранится именем, а не числом (§8), поэтому печатается как `Enums.Stun.Medium`:
--- `Info.Stun.Priority` ждёт число, а не строку.
local function enumLiteral(ctx: Ctx, name: string, value: any): string
	if type(value) ~= "string" then return literal(value) end
	use(ctx, "Enums")
	return `Enums.{name}.{value}`
end

--- Одна строка поля. `Priority` — единственное строковое поле `Info`, которое при
--- этом не строка, а число; `RelativePart` / `RelativeTowards`, наоборот, остаются
--- строками, потому что так их читает `Hooks/Knockback.luau`.
local function fieldLine(ctx: Ctx, name: string, value: any): string
	if name == "Priority" and type(value) == "string" then
		return `Priority = {enumLiteral(ctx, "Stun", value)},`
	elseif name == "RelativePart" or name == "RelativeTowards" then
		return `{name} = {quoted(value)},`
	end

	return `{name} = {literal(value)},`
end

-- INFO И ATTACKINFO ----------------------------------------------------------

--- Значения `ProcessAttack` копируются в `AttackInfo` шапки: первое непустое поле
--- побеждает, потому что два вызова удара с разными значениями нельзя честно
--- свести к одному, а `AttackInfo` читают `Grab.luau:74` и `TEMPLATE.luau:57`.
--- `Stun.Duration` → `Stun`, `Duration`; у корневого ключа группа равна `nil`.
---
--- Тот же разбор, что в `codec.splitKey`, но здесь он нужен для раскладки шапки, а не
--- для JSON: имена свойств приходят плоскими и с путём группы внутри ключа (§8).
local function splitInfoKey(key: string): (string?, string)
	local dot = string.find(key, ".", 1, true)
	if not dot then return nil, key end
	return string.sub(key, 1, dot - 1), string.sub(key, dot + 1)
end

--- Значения `AttackInfoDefaults` скилла раскладываются по тому же пути, что и свойства
--- блока, поэтому дефолт секции и дефолт её поля ведут себя одинаково.
---
--- Ключ без точки (`Damage`) идёт в корень, с точкой (`Stun.Duration`) — в секцию;
--- неизвестные ключи игнорируются, потому что выводить их некуда, а валидатор
--- отсекает их раньше (§9).
local function seedAttackInfoDefaults(ctx: Ctx, defaults: any)
	if type(defaults) ~= "table" then return end

	for key, value in defaults do
		if type(key) ~= "string" or not isPrintable(value) then continue end

		local group, field = splitInfoKey(key)

		if group == nil then
			if ctx.attackInfo[field] == nil then ctx.attackInfo[field] = value end
		else
			local section = ctx.attackInfo[group]
			if type(section) ~= "table" then
				section = {}
				ctx.attackInfo[group] = section
			end

			if section[field] == nil then section[field] = value end
		end
	end
end

local function mergeAttackInfo(ctx: Ctx, block: any)
	for _, name in { "Priority", "Damage" } do
		local value = propertyOf(block, name)
		if value ~= nil and ctx.attackInfo[name] == nil and isPrintable(value) then
			ctx.attackInfo[name] = value
		end
	end

	for _, group in INFO_GROUPS :: { { any } } do
		local name, fields = group[1], group[2] :: { string }

		for _, field in fields do
			local value = propertyOf(block, `{name}.{field}`)
			if value == nil or not isPrintable(value) then continue end

			local section = ctx.attackInfo[name]
			if type(section) ~= "table" then
				section = {}
				ctx.attackInfo[name] = section
			end

			if section[field] == nil then section[field] = value end
		end
	end
end

--- Секция группы (`Stun`, `Knockback`, …). Печатается только если заполнено хотя бы
--- одно поле, а поля внутри сдвинуты на один таб.
local function infoGroupLines(
	ctx: Ctx,
	block: any,
	path: { string | number },
	level: number
): { string }
	local lines: { string } = {}

	for _, group in INFO_GROUPS :: { { any } } do
		local name, fields = group[1], group[2] :: { string }
		local inner: { string } = {}

		for _, field in fields do
			local value = valueOf(ctx, block, `{name}.{field}`, path)
			if value ~= nil then table.insert(inner, fieldLine(ctx, field, value)) end
		end

		if #inner > 0 then
			table.insert(lines, `{name} = \{`)
			extend(lines, indented(inner, level + 1))
			table.insert(lines, "},")
		end
	end

	return lines
end

--- `Info` целиком. Собирается заново на каждый вызов `Attack` (§6): хуки мутируют
--- переданную таблицу, и общая таблица протекла бы в следующий кадр.
local function infoLines(ctx: Ctx, block: any, path: { string | number }, level: number): { string }
	local lines: { string } = {}

	for _, name in { "Priority", "Damage" } do
		local value = valueOf(ctx, block, name, path)
		if value ~= nil then table.insert(lines, fieldLine(ctx, name, value)) end
	end

	extend(lines, infoGroupLines(ctx, block, path, level))
	mergeAttackInfo(ctx, block)

	if #lines == 0 then return { "Info = {}," } end

	return indented(lines, level)
end

--- Тело таблицы `AttackInfo` шапки: те же ключи и тот же порядок, что у `Info`.
local function attackInfoLines(ctx: Ctx, level: number): { string }
	local info = ctx.attackInfo
	local lines: { string } = {}

	for _, name in { "Priority", "Damage" } do
		if info[name] ~= nil then table.insert(lines, fieldLine(ctx, name, info[name])) end
	end

	for _, group in INFO_GROUPS :: { { any } } do
		local name = group[1]
		local section = info[name]
		if type(section) ~= "table" then continue end

		local inner: { string } = {}
		for _, field in group[2] :: { string } do
			if section[field] ~= nil then
				table.insert(inner, fieldLine(ctx, field, section[field]))
			end
		end

		if #inner > 0 then
			table.insert(lines, `{name} = \{`)
			extend(lines, indented(inner, level + 1))
			table.insert(lines, "},")
		end
	end

	return indented(lines, level)
end

-- ОБХОД ДЕРЕВА --------------------------------------------------------------

local emitBlock: (Ctx, any, { string | number }, number, number, Scope) -> { string }

--- Поверхностная копия блока со списком слотов. Копия нужна, чтобы служебное поле
--- `__slots` не попало в blueprint, который может уйти обратно в UI или в JSON.
local function withSlots(block: any, slots: { string }): any
	if type(block) ~= "table" then return block end

	local copy = table.clone(block)
	copy.__slots = slots
	return copy
end

--- Список блоков слота. Отсутствующий слот — пустой список, а не ошибка: пустые
--- слоты у `Branch` и `ProcessAttack` законны.
local function slotBlocks(block: any, slot: string): { any }
	local children = block.Children
	if type(children) ~= "table" then return {} end

	local list = children[slot]
	if type(list) ~= "table" then return {} end

	local result: { any } = {}
	for _, child in list do
		table.insert(result, child)
	end

	return result
end

--- Сколько блоков каждого «создающего ручку» типа в дереве.
---
--- `AddArmor` и `CreateGrab` кладут `Buttler` в именованный слот, номер которого
--- выдаёт `localName`. Соответствующие `RemoveArmor` / `ReleaseGrab` обязаны знать,
--- сколько таких слотов вообще появится, иначе отменитель сможет сослаться только на
--- один из них. Подсчёт идёт по всему дереву, включая вложенные блоки: слот
--- получает любой экземпляр, независимо от того, где он лежит.
local function countHandles(blocks: { any }): { [string]: number }
	local result: { [string]: number } = {}
	if type(blocks) ~= "table" then return result end

	local function walk(list: { any })
		if type(list) ~= "table" then return end

		for _, block in list do
			if type(block) ~= "table" then continue end

			local blockType = block.Type
			if type(blockType) == "string" then result[blockType] = (result[blockType] or 0) + 1 end

			local children = block.Children
			if type(children) == "table" then
				for _, nested in children do
					walk(nested)
				end
			end
		end
	end

	walk(blocks)
	return result
end

--- Путь к вложенным блокам слота: `{ "Blocks", 0, "Children", "OnSuccess" }`.
local function childPath(path: { string | number }, slot: string): { string | number }
	local result = table.clone(path) :: { string | number }
	table.insert(result, "Children")
	table.insert(result, slot)
	return result
end

--- Вложенные блоки одного слота. Пустой слот пропускается целиком: пустой `if` или
--- `for` в выводе только шумит. `level` — отступ тела каждого ребёнка.
local function emitSlot(
	ctx: Ctx,
	blocks: { any },
	parentStart: number,
	slotPath: { string | number },
	level: number,
	scope: Scope
): { string }
	local lines: { string } = {}

	for index, child in blocks do
		local path = table.clone(slotPath) :: { string | number }
		table.insert(path, index)

		extend(lines, emitBlock(ctx, child, path, parentStart, level, scope))
		if index < #blocks then table.insert(lines, "") end
	end

	return lines
end

--- Кадр блока. Приводится к целому и не меньше кадра родителя: иначе вложенный блок
--- выполнился бы раньше того, что его содержит (§7, пункт 1).
local function blockStart(
	ctx: Ctx,
	block: any,
	path: { string | number },
	parentStart: number
): number
	local raw = block.StartFrame
	if type(raw) ~= "number" then
		report(
			ctx,
			"EMIT_FRAME",
			`{tostring(block.Type)} has no StartFrame`,
			path,
			block.Id,
			"StartFrame"
		)
		return parentStart
	end

	local start = math.max(0, math.floor(raw))
	if start < parentStart then return parentStart end
	return start
end

local function blockEnd(ctx: Ctx, block: any, path: { string | number }, start: number): number
	local raw = block.EndFrame
	if type(raw) ~= "number" then return start end

	local finish = math.floor(raw)
	if finish < start then
		report(
			ctx,
			"EMIT_FRAME",
			"Repeat ends before it starts",
			propertyPath(path, "EndFrame"),
			block.Id,
			"EndFrame"
		)
		return start
	end

	return finish
end

-- БЛОКИ ---------------------------------------------------------------------

--- `Hitbox`: запрос попаданий и обрезка до `MaxTargets`. Обрезка делается вручную:
--- в `HitboxData.Info` такого поля нет, поэтому лишнее пришлось бы отсекать здесь
--- (§5, Query). `Skill` обязателен — без него `Bot.luau:198` не знает тегов (§2.9).
local function emitHitbox(ctx: Ctx, block: any, path: { string | number }): { string }
	local targets = localName(ctx, "Targets")
	local hit = localName(ctx, "Hit")

	local info: { string } = {}

	-- `Shape` в `Info` не печатается: форму задаёт ТИП `Size`. Задача эмиттера —
	-- не допустить, чтобы объявленная форма и фактический тип разошлись: `Ball` с
	-- `Vector3` молча остался бы кубом, а `Box` с числом — сферой, и ни то, ни другое
	-- не сообщило бы пользователю ничего. Валидатор ловит то же (E28) для UI, здесь
	-- проверка нужна потому, что эмиттер может быть вызван напрямую.
	local shape = valueOf(ctx, block, "Shape", path)
	if shape ~= nil and shape ~= "Box" and shape ~= "Ball" then shape = "Box" end

	local size = valueOf(ctx, block, "Size", path)
	if size ~= nil then
		local sizeIsNumber = type(size) == "number"
		local wantsNumber = shape == "Ball"

		-- Сверка только когда форма объявлена ЯВНО. Файл версии 1 поля `Shape` не
		-- знает и форму выводит из типа `Size`, как и делает сервис; трактовать
		-- отсутствие поля как `Box` значило бы сломать все старые сферические скиллы.
		if shape ~= nil and wantsNumber ~= sizeIsNumber then
			report(
				ctx,
				"EMIT_VALUE",
				`Hitbox {shape} needs Size of type {if wantsNumber then "number" else "Vector3"}, got {type(
					size
				)}`,
				propertyPath(path, "Size"),
				block.Id,
				"Size"
			)
			size = nil
		else
			table.insert(info, `\tSize = {literal(size)},`)
		end
	end

	local origin = valueOf(ctx, block, "Origin", path)
	if origin ~= nil then table.insert(info, `\tOrigin = {cframeLiteral(origin)},`) end

	local offset = valueOf(ctx, block, "Offset", path)
	if offset ~= nil and not isIdentityCFrame(offset) then
		table.insert(info, `\tOffset = {cframeLiteral(offset)},`)
	end

	local scope = valueOf(ctx, block, "MaxTargets", path)
	local all = scope == "All"

	if scope ~= "Nearest" and scope ~= "All" then
		-- Отсутствует или мусор: дефолт реестра — `Nearest`. Подставлять его молча
		-- здесь нельзя было бы из-за типов, но и полагаться на реестр тоже не стоит:
		-- `valueOf` уже вернул `nil`, и «ближайшая» — единственное разумное чтение.
		scope = "Nearest"
	end

	-- `Nearest` — это «первая цель в том порядке, который вернул сервис». Ближайшей
	-- её делает только сортировка, поэтому при `Nearest` она принудительно включается:
	-- иначе имя обещало бы расстояние, которого в выдаче нет, и результат зависел бы
	-- от того, как `CombatService:Hitbox` решил перечислить цели.
	local sortDistance = valueOf(ctx, block, "SortByDistance", path)
	if scope == "Nearest" then sortDistance = true end

	-- `SortByDistance` печатается всегда: при `Nearest` он принудительно `true`, при
	-- `All` — то, что задал пользователь, и «все цели» при любом значении выглядит
	-- одинаково. Раньше значение сливалось с циклом и принудительную сортировку
	-- тогда приходилось бы дублировать.
	table.insert(info, `\tSortByDistance = {tostring(sortDistance)}`)

	for _, name in { "CanQueryCaster", "MovementCorrection", "Debug" } do
		local value = valueOf(ctx, block, name, path)
		if value ~= nil then table.insert(info, `\t{name} = {tostring(value)},`) end
	end

	local lines: { string } = {
		`local {targets} = CombatService:Hitbox(\{`,
		"\tSkill = self,",
		"\tCaster = character,",
		"\tInfo = {",
	}
	extend(lines, info)
	extend(lines, {
		"\t},",
		"})",
		"",
		`local {hit} = \{\}`,
		`for _, Target in {targets} do`,
	})

	-- При `All` цикл идёт по всем целям и обрываться не должен — ради этого `break`
	-- раньше и существовал, и ради этого он не печатается сейчас.
	if not all then table.insert(lines, `\tif #{hit} >= 1 then break end`) end

	extend(lines, {
		`\ttable.insert({hit}, Target)`,
		"end",
		"",
		"seq.Ctx = seq.Ctx or {}",
		`seq.Ctx.Targets = {hit}`,
	})

	return lines
end

--- `ProcessAttack`: один вызов `Attack` на каждую цель. Условия слотов статичны,
--- поэтому все семь `if` известны заранее и пустые просто не печатаются (§7).
local function emitProcessAttack(
	ctx: Ctx,
	block: any,
	path: { string | number },
	start: number,
	level: number
): { string }
	local targets = localName(ctx, "Targets")
	local lines: { string } = {
		`local {targets} = seq.Ctx and seq.Ctx.Targets or \{\}`,
		"",
		`for _, Target in {targets} do`,
		"\tCombatService:Attack({",
		"\t\tAttacker = character,",
		"\t\tVictim = Target,",
		"\t\tInfo = {",
	}

	extend(lines, infoLines(ctx, block, path, 3))
	extend(lines, {
		"\t\t},",
		"\t}",
	})

	local inner = table.clone(path) :: { string | number }
	table.insert(inner, "Children")

	local scope: Scope = { Target = true, Data = true }
	local bodies: { { string } } = {}

	-- `SkipBlocked` сужает ТОЛЬКО условие `OnSuccess`. Остальные слоты не трогаются:
	-- реакция на блок должна остаться доступной, иначе блок с `SkipBlocked` перестал бы
	-- различать исходы и вёлся бы как «всегда успех».
	--
	-- Условие дописывается на этапе генерации, а не читается в рантайме, потому что
	-- слоты статичны и их условия известны заранее (§7). `PerfectBlocked` в список
	-- попал для полноты: сегодня перфект-блок уже обнуляет `Continue` (`Block.luau:40`),
	-- поэтому в `OnSuccess` он и не доходит, но полагаться на это — значит зависеть от
	-- порядка хуков в чужом файле.
	local skipBlocked = valueOf(ctx, block, "SkipBlocked", path) == true

	for _, entry in ATTACK_SLOTS do
		local slot, condition = entry[1], entry[2]
		local blocks = slotBlocks(block, slot)
		if #blocks == 0 then continue end

		local slotPath = table.clone(inner) :: { string | number }
		table.insert(slotPath, slot)

		local body = emitSlot(ctx, blocks, start, slotPath, level + 2, scope)
		if #body > 0 then
			if skipBlocked and slot == "OnSuccess" then
				condition =
					`{condition} and not Data.State.Blocked and not Data.State.PerfectBlocked`
			end

			table.insert(bodies, concat({ { `if {condition} then` }, body, { "end" } }))
		end
	end

	if #bodies == 0 then
		table.insert(lines, "\t):andThen(function() end)")
	else
		table.insert(lines, "\t):andThen(function(Data)")

		for index, body in bodies do
			if index > 1 then table.insert(lines, "") end
			extend(lines, indented(body, 2))
		end

		table.insert(lines, "\tend)")
	end

	table.insert(lines, "end")
	return lines
end

--- Блоки категории `State`: все они — один `AddParameter`, обёрнутый в `seq.Cleaner`,
--- чтобы параметр вернулся к дефолту при остановке sequence (§7, Cleanup).
local function emitStateParameter(ctx: Ctx, block: any, path: { string | number }): { string }
	local entry = STATE_PARAMETERS[block.Type]
	local parameter = entry.parameter
	local field = entry.field

	local value = valueOf(ctx, block, field, path)
	if value == nil then
		if block.Type == "SetIFrames" then
			value = "True"
		elseif block.Type == "SetNoCollision" then
			value = NO_COLLISION_FALLBACK
		else
			report(
				ctx,
				"EMIT_VALUE",
				`{field} of {tostring(block.Type)} is not set`,
				propertyPath(path, field),
				block.Id,
				field
			)
			return {}
		end
	end

	local printed = if block.Type == "SetIFrames"
		then enumLiteral(ctx, "IFrames", value)
		else literal(value)
	return { `seq.Cleaner:Add(character:AddParameter({quoted(parameter)}, {printed}))` }
end

--- `AddArmor` кладёт ручку в ИМЕНОВАННЫЙ слот `Buttler`, а не в локальную переменную.
---
--- Раньше ручка попадала в `local Armor1`, объявленный внутри callback'а кадра, а
--- значит была недостижима из любого более позднего кадра: отменить броню посреди
--- sequence было нечем, кроме как дождаться конца. `Set` делает слот адресуемым по
--- имени, и `RemoveArmor` может его снять (`Buttler.luau:342` — безопасный no-op,
--- если слота нет, в том числе когда броня уже снята или не выдавалась).
local function emitAddArmor(ctx: Ctx, _block: any, _path: { string | number }): { string }
	local armor = localName(ctx, "Armor")

	return { `seq.Cleaner:Set("{armor}", CombatService:AddArmor(character))` }
end

--- `RemoveArmor`: снимает ВСЕ брони, выданные в этой последовательности.
---
--- Имена слотов известны заранее (`countHandles`), а не по порядку эмиссии: иначе
--- отменитель, стоящий в дереве раньше `AddArmor`, сослался бы на слот, который ещё
--- не существует, и тихо ничего не сделал бы.
local function emitRemoveArmor(ctx: Ctx, _block: any, _path: { string | number }): { string }
	local total = ctx.handles.AddArmor or 0
	if total == 0 then return {} end

	local lines: { string } = {}
	for index = 1, total do
		table.insert(lines, `seq.Cleaner:Remove("Armor{index}")`)
	end

	return lines
end

--- `CreateGrab` возвращает одну `Buttler`-ручку на обоих участников: и `IFrames`, и
--- `NoCollision`, и опциональный `Restrain`, и `AlignPosition` с вложениями, которые и
--- разрывают физическую связь. Отпустить её — значит очистить этот единственный
--- объект, отдельных ручек на атакующего и жертву нет.
---
--- Слот именованный по той же причине, что и у брони: без адресуемости `ReleaseGrab`
--- не смог бы ничего отменить, а отмена до конца sequence — это и есть «отпустить
--- посреди броска».
local function emitCreateGrab(ctx: Ctx, block: any, path: { string | number }): { string }
	local grabData = localName(ctx, "GrabData")
	local grabSlot = localName(ctx, "Grab")
	local attackerRestrain = valueOf(ctx, block, "AttackerRestrain", path)
	local victimRestrain = valueOf(ctx, block, "VictimRestrain", path)
	local bindMode = valueOf(ctx, block, "BindMode", path)
	local offset = valueOf(ctx, block, "Offset", path)

	local lines: { string } = { `local {grabData} = \{`, "\tAttacker = {" }
	if attackerRestrain ~= nil then
		table.insert(lines, `\t\tRestrain = {tostring(attackerRestrain)},`)
	end
	table.insert(lines, "\t},")

	table.insert(lines, "\tVictim = {")
	if victimRestrain ~= nil then
		table.insert(lines, `\t\tRestrain = {tostring(victimRestrain)},`)
	end

	if bindMode == "RootToRoot" then
		table.insert(lines, "\t\tBind = {")
		table.insert(lines, "\t\t\tPart0 = RootPart,")
		table.insert(lines, "\t\t\tPart1 = Target.RootPart,")
		if offset ~= nil then table.insert(lines, `\t\t\tOffset = {cframeLiteral(offset)},`) end
		table.insert(lines, "\t\t},")
	end

	extend(lines, {
		"\t},",
		"}",
		`seq.Cleaner:Set("{grabSlot}", CombatService:CreateGrab(character, Target, {grabData}))`,
	})

	return lines
end

--- `ReleaseGrab`: снимает все хваты этой последовательности.
---
--- Счётчики здесь взаимозаменяемы с брони не случайно: обе сущности живут до конца
--- sequence и обе должны уметь закончиться раньше. `Buttler:Remove` на отсутствующем
--- имени — no-op, поэтому отпускание без предварительного захвата не падает.
local function emitReleaseGrab(ctx: Ctx, _block: any, _path: { string | number }): { string }
	local total = ctx.handles.CreateGrab or 0
	if total == 0 then return {} end

	local lines: { string } = {}
	for index = 1, total do
		table.insert(lines, `seq.Cleaner:Remove("Grab{index}")`)
	end

	return lines
end

--- Ключ ассета анимации по `Id` слота. `Id` локален для blueprint, а в `Assets` лежит
--- `AnimationId` (§4), поэтому резолв выполняется здесь, на этапе генерации.
local function animationKey(
	ctx: Ctx,
	block: any,
	path: { string | number }
): (string?, number?, number?)
	local slotId = propertyOf(block, "Slot")
	if type(slotId) ~= "string" then return nil, nil, nil end

	local key = ctx.slots[slotId]
	if key == nil then
		report(
			ctx,
			"EMIT_SLOT",
			`Animation slot {slotId} does not exist`,
			propertyPath(path, "Slot"),
			block.Id,
			"Slot"
		)
		return nil, nil, nil
	end

	return key, ctx.slotSpeed[slotId], ctx.slotFade[slotId]
end

local function emitPlayAnimation(ctx: Ctx, block: any, path: { string | number }): { string }
	use(ctx, "VFXService")
	use(ctx, "Players")
	use(ctx, "Anims")

	local key, slotSpeed = animationKey(ctx, block, path)
	if key == nil then return {} end

	local speed = valueOf(ctx, block, "Speed", path)
	local speedText = if speed ~= nil
		then num(speed)
		elseif slotSpeed ~= nil then num(slotSpeed)
		else "seq.Speed"

	local asset = quoted(key)
	return {
		`VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, \{`,
		`\tAnimation = Anims[{asset}].Animation,`,
		`\tSpeed = {speedText},`,
		"})",
		"",
		"seq.Cleaner:Add(function()",
		`\tVFXService:StopEffect(Players:GetPlayers(), "Animation", character.instance, \{`,
		`\t\tAnimation = Anims[{asset}].Animation,`,
		"\t})",
		"end)",
	}
end

local function emitStopAnimation(ctx: Ctx, block: any, path: { string | number }): { string }
	use(ctx, "VFXService")
	use(ctx, "Players")
	use(ctx, "Anims")

	local key, _, slotFade = animationKey(ctx, block, path)
	if key == nil then return {} end

	local fade = valueOf(ctx, block, "FadeTime", path)
	local fadeText = if fade ~= nil
		then num(fade)
		elseif slotFade ~= nil then num(slotFade)
		else num(0.3)

	return {
		`VFXService:StopEffect(Players:GetPlayers(), "Animation", character.instance, \{`,
		`\tAnimation = Anims[{quoted(key)}].Animation,`,
		`\tFadeTime = {fadeText},`,
		"})",
	}
end

local function emitPlaySound(ctx: Ctx, block: any, path: { string | number }): { string }
	use(ctx, "VFXService")
	use(ctx, "Players")
	use(ctx, "Sounds")

	-- Ключ резолвится так же, как у анимации: сначала `Slot` (новый путь, файл 2),
	-- потом прямой `Sound` (файл 1). Ровно одно из двух гарантирует валидатор, но
	-- эмиттер эмитит и при экспорте «как есть», поэтому оба пути обязаны работать.
	local key: string?
	local slotId = propertyOf(block, "Slot")

	if type(slotId) == "string" and slotId ~= "" then
		key = ctx.soundSlots[slotId]

		if key == nil then
			report(
				ctx,
				"EMIT_SLOT",
				`Sound slot {slotId} does not exist`,
				propertyPath(path, "Slot"),
				block.Id,
				"Slot"
			)
			return {}
		end
	else
		key = valueOf(ctx, block, "Sound", path)
	end

	if type(key) ~= "string" then
		report(ctx, "EMIT_ASSET", "PlaySound without a sound", path, block.Id, "Sound")
		return {}
	end

	local data: { string } = { `\tSound = Sounds[{quoted(key)}].Sound,` }
	for _, name in { "Volume", "MaxDistance", "MinDistance" } do
		local value = valueOf(ctx, block, name, path)
		if value ~= nil then table.insert(data, `\t{name} = {literal(value)},`) end
	end

	local lines: { string } =
		{ `VFXService:StartEffect(Players:GetPlayers(), "Sound", RootPart, \{` }
	extend(lines, data)
	extend(lines, {
		"})",
		"",
		"seq.Cleaner:Add(function()",
		-- onStop вторым аргументом ждёт сам инстанс Sound, а не таблицу `Sounds[key]`:
		-- `effects/Sound.luau:54` читает `Sound.Name` и обрезал бы весь скилл.
		`\tVFXService:StopEffect(Players:GetPlayers(), "Sound", RootPart, Sounds[{quoted(
			key
		)}].Sound)`,
		"end)",
	})

	return lines
end

--- `StopSound` работает ровно как `StopAnimation`: один вызов `VFXService:StopEffect`,
--- инстанс передаётся по ссылке на тот же ключ в `Assets.Sounds`. Блок не регистрирует
--- собственную очистку — сам и останавливает.
local function emitStopSound(ctx: Ctx, block: any, path: { string | number }): { string }
	use(ctx, "VFXService")
	use(ctx, "Players")
	use(ctx, "Sounds")

	local key: string?
	local slotId = propertyOf(block, "Slot")

	if type(slotId) == "string" and slotId ~= "" then
		key = ctx.soundSlots[slotId]

		if key == nil then
			report(
				ctx,
				"EMIT_SLOT",
				`Sound slot {slotId} does not exist`,
				propertyPath(path, "Slot"),
				block.Id,
				"Slot"
			)
			return {}
		end
	else
		key = valueOf(ctx, block, "Sound", path)
	end

	if type(key) ~= "string" then
		report(ctx, "EMIT_ASSET", "StopSound without a sound", path, block.Id, "Sound")
		return {}
	end

	return {
		`VFXService:StopEffect(Players:GetPlayers(), "Sound", RootPart, Sounds[{quoted(key)}].Sound)`,
	}
end

--- `EmitParticle` и `EmitFolder` умеют вешаться на цель. Тогда блоку нужна цель в
--- области видимости, и вне цикла по целям эмиттер оборачивает его циклом сам.
local function originExpression(block: any): string
	if propertyOf(block, "Origin") == "Target" then return "Target.RootPart" end
	return "RootPart.CFrame"
end

local function actorExpression(block: any): string
	if propertyOf(block, "Origin") == "Target" then return "Target.instance" end
	return "character.instance"
end

local function emitEmitParticle(ctx: Ctx, block: any, path: { string | number }): { string }
	use(ctx, "VFXService")
	use(ctx, "Players")
	use(ctx, "Models")
	use(ctx, "Uuid")

	local key = valueOf(ctx, block, "Particle", path)
	if type(key) ~= "string" then
		report(ctx, "EMIT_ASSET", "EmitParticle without a model", path, block.Id, "Particle")
		return {}
	end

	local uuid = localName(ctx, "ParticleUUID")
	local data: { string } = {
		`\tUUID = {uuid},`,
		`\tParticle = Models[{quoted(key)}],`,
		`\tOrigin = {originExpression(block)},`,
	}

	local offset = valueOf(ctx, block, "Offset", path)
	if offset ~= nil and not isIdentityCFrame(offset) then
		table.insert(data, `\tOffset = {cframeLiteral(offset)},`)
	end

	local useForge = valueOf(ctx, block, "UseForge", path)
	if useForge ~= nil then table.insert(data, `\tUseForge = {tostring(useForge)},`) end

	local lines: { string } = {
		`local {uuid} = NextUuid()`,
		"",
		`VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", \{`,
	}
	extend(lines, data)
	extend(lines, {
		"})",
		"",
		"seq.Cleaner:Add(function()",
		`\tVFXService:StopEffect(Players:GetPlayers(), "EmitParticle", {uuid})`,
		"end)",
	})

	return lines
end

--- `EmitFolder` принимает `uuid` строкой (`effects/EmitFolder.luau:8`), а счётчик
--- эмиттера числовой, поэтому он приводится к строке явно.
local function emitEmitFolder(ctx: Ctx, block: any, path: { string | number }): { string }
	use(ctx, "VFXService")
	use(ctx, "Players")
	use(ctx, "Models")
	use(ctx, "Uuid")

	local key = valueOf(ctx, block, "Folder", path)
	if type(key) ~= "string" then
		report(ctx, "EMIT_ASSET", "EmitFolder without a model", path, block.Id, "Folder")
		return {}
	end

	local uuid = localName(ctx, "FolderUUID")
	local actor = actorExpression(block)

	return {
		`local {uuid} = tostring(NextUuid())`,
		"",
		`VFXService:StartEffect(Players:GetPlayers(), "EmitFolder", {actor}, Models[{quoted(key)}], {uuid})`,
		"",
		"seq.Cleaner:Add(function()",
		`\tVFXService:StopEffect(Players:GetPlayers(), "EmitFolder", {actor}, {uuid})`,
		"end)",
	}
end

--- `Highlight` не останавливается по `UUID`: `Lifetime` обязателен, а
--- `effects/Highlight.luau:53-55` кладёт Highlight в кэш только в ветке `elseif`,
--- куда срок жизни не доходит, — снимает его таймер.
local function emitHighlight(ctx: Ctx, block: any, path: { string | number }): { string }
	use(ctx, "VFXService")
	use(ctx, "Players")

	local data: { string } = {}
	for _, name in { "FillColor", "OutlineColor", "FillTransparency", "OutlineTransparency" } do
		local value = valueOf(ctx, block, name, path)
		if value ~= nil then table.insert(data, `\t{name} = {literal(value)},`) end
	end

	local lifetime = valueOf(ctx, block, "Lifetime", path)
	if lifetime ~= nil then table.insert(data, `\tLifetime = {literal(lifetime)},`) end

	local lines: { string } = {
		`VFXService:StartEffect(Players:GetPlayers(), "Highlight", character.instance, \{`,
	}
	extend(lines, data)
	table.insert(lines, "})")

	return lines
end

local function emitClearTargets(_ctx: Ctx, _block: any, _path: { string | number }): { string }
	return { "seq.Ctx = seq.Ctx or {}", "seq.Ctx.Targets = {}" }
end

--- `Branch`: условие попадает в сгенерированный файл дословно. Это осознанный escape
--- hatch, поэтому такие блоки помечаются предупреждением W5 (§9).
local function emitBranch(
	ctx: Ctx,
	block: any,
	path: { string | number },
	parentStart: number,
	level: number,
	scope: Scope
): { string }
	local condition = valueOf(ctx, block, "Condition", path)
	if type(condition) ~= "string" or string.match(condition, "^%s*$") ~= nil then
		report(ctx, "EMIT_VALUE", "Branch without a condition", path, block.Id, "Condition")
		return {}
	end

	local hasTrue = #slotBlocks(block, "True") > 0
	local hasFalse = #slotBlocks(block, "False") > 0
	if not hasTrue and not hasFalse then return {} end

	local start = blockStart(ctx, block, path, parentStart)

	local trueBody = if hasTrue
		then emitSlot(
			ctx,
			slotBlocks(block, "True"),
			start,
			childPath(path, "True"),
			level + 1,
			scope
		)
		else {}
	local falseBody = if hasFalse
		then emitSlot(
			ctx,
			slotBlocks(block, "False"),
			start,
			childPath(path, "False"),
			level + 1,
			scope
		)
		else {}

	if hasTrue and hasFalse then
		return concat({
			{ `if ({condition}) then` },
			trueBody,
			{ "else" },
			falseBody,
			{ "end" },
		})
	elseif hasTrue then
		return concat({ { `if ({condition}) then` }, trueBody, { "end" } })
	end

	return concat({ { `if not ({condition}) then` }, falseBody, { "end" } })
end

--- `CustomCallback`: код вставляется как есть. Отступы выравниваются по месту, но
--- содержимое не трогается — иначе escape hatch не справлял бы своей задачи.
--- Разбиение текста на строки. string.split здесь не используется: в Roblox он
--- возвращает таблицу частей, а в lune — итератор пар (индекс, часть), поэтому
--- один и тот же or a, b in в этих средах отдаёт разные значения.
local function splitLines(text: string): { string }
	local lines: { string } = {}
	local from = 1

	while true do
		local newline = string.find(text, "\n", from, true)
		if newline == nil then
			table.insert(lines, string.sub(text, from))
			break
		end

		table.insert(lines, string.sub(text, from, newline - 1))
		from = newline + 1
	end

	return lines
end

local function emitCustomCallback(ctx: Ctx, block: any, path: { string | number }): { string }
	local code = valueOf(ctx, block, "Code", path)
	if type(code) ~= "string" then
		report(ctx, "EMIT_VALUE", "CustomCallback without code", path, block.Id, "Code")
		return {}
	end

	local lines: { string } = {}
	for _, raw in splitLines(code) do
		local trimmed = string.match(raw, "^%s*(.-)%s*$") :: string
		table.insert(lines, if trimmed == "" then "" else trimmed)
	end

	while #lines > 0 and lines[1] == "" do
		table.remove(lines, 1)
	end
	while #lines > 0 and lines[#lines] == "" do
		table.remove(lines)
	end

	return lines
end

--- `Repeat`. На верхнем уровне это отдельный много-кадровый элемент `{start, fn, end}`;
--- внутри другого `Repeat` диапазон проверяется в теле — иначе вложенный диапазон
--- выполнился бы один раз, на кадре родителя.
local function emitRepeat(
	ctx: Ctx,
	block: any,
	path: { string | number },
	parentStart: number,
	level: number,
	scope: Scope
): { string }
	local start = blockStart(ctx, block, path, parentStart)
	local finish = blockEnd(ctx, block, path, start)

	local body =
		emitSlot(ctx, slotBlocks(block, "Body"), start, childPath(path, "Body"), level + 1, scope)
	if #body == 0 then return {} end

	return concat({
		{ `if frame >= {num(start)} and frame <= {num(finish)} then` },
		body,
		{ "end" },
	})
end

-- ДИСПЕТЧЕР ------------------------------------------------------------------

local SCALAR_EMITTERS = {
	PlayAnimation = emitPlayAnimation,
	StopAnimation = emitStopAnimation,
	PlaySound = emitPlaySound,
	StopSound = emitStopSound,
	EmitParticle = emitEmitParticle,
	EmitFolder = emitEmitFolder,
	Highlight = emitHighlight,
	ClearTargets = emitClearTargets,
	AddArmor = emitAddArmor,
	RemoveArmor = emitRemoveArmor,
	ReleaseGrab = emitReleaseGrab,
	CustomCallback = emitCustomCallback,
}

--- Нужен ли блоку цикл по целям. Внутри `ProcessAttack` он уже есть, поэтому
--- проверка идёт по области видимости, а не по типу блока.
local function needsTargetLoop(block: any, scope: Scope): boolean
	if scope.Target then return false end

	local blockType = block.Type
	if blockType == "CreateGrab" then return true end
	if not TARGET_ORIGIN[blockType] then return false end

	return propertyOf(block, "Origin") == "Target"
end

--- Тело блока с учётом отступа `level`: каждый эмиттер печатает строки от нуля, а
--- отступ добавляется здесь — иначе вложенный блок выехал бы на верхний уровень.
emitBlock = function(
	ctx: Ctx,
	block: any,
	path: { string | number },
	parentStart: number,
	level: number,
	scope: Scope
): { string }
	if type(block) ~= "table" then return {} end

	local blockType = block.Type
	local prepared = withSlots(block, CONTAINER_SLOTS[blockType] or {})
	local body: { string } = {}

	-- `Wait` — только маркер конца: в `Frames` он не попадает, влияет лишь на `maxFrame`.
	if blockType == "Wait" then
		return body
	elseif blockType == "ProcessAttack" then
		local start = blockStart(ctx, prepared, path, parentStart)
		body = emitProcessAttack(ctx, prepared, path, start, level)
	elseif blockType == "Repeat" then
		body = emitRepeat(ctx, prepared, path, parentStart, level, scope)
	elseif blockType == "Branch" then
		body = emitBranch(ctx, prepared, path, parentStart, level, scope)
	elseif needsTargetLoop(prepared, scope) then
		local targets = localName(ctx, "Targets")
		local inner: Scope = { Target = true, Data = scope.Data }

		local lines: { string } = {
			`local {targets} = seq.Ctx and seq.Ctx.Targets or \{\}`,
			"",
			`for _, Target in {targets} do`,
		}
		extend(lines, indented(emitBlock(ctx, prepared, path, parentStart, level + 1, inner), 1))
		table.insert(lines, "end")

		body = lines
	elseif blockType == "Hitbox" then
		body = emitHitbox(ctx, prepared, path)
	elseif STATE_PARAMETERS[blockType] ~= nil then
		body = emitStateParameter(ctx, prepared, path)
	elseif SCALAR_EMITTERS[blockType] ~= nil then
		body = SCALAR_EMITTERS[blockType](ctx, prepared, path)
	elseif blockType == "CreateGrab" then
		body = emitCreateGrab(ctx, prepared, path)
	else
		report(ctx, "EMIT_BLOCK", `Unknown block type {tostring(blockType)}`, path, block.Id)
	end

	return indented(body, level)
end

-- СБОРКА КАДРОВ -------------------------------------------------------------

--- Все блоки поддерева в порядке обхода: из них строится `Preview`.
local function flattenBlocks(block: any, result: { any }): { any }
	if type(block) ~= "table" then return result end

	table.insert(result, block)

	for _, slot in (block.__slots or {}) :: { string } do
		for _, child in slotBlocks(block, slot) do
			flattenBlocks(child, result)
		end
	end

	return result
end

--- Максимальный кадр в поддереве. Именно он, а не кадр последнего блока, определяет,
--- сколько кадров живёт скилл: `Repeat` должен продолжаться до конца, а `Wait` —
--- просто продлевать скилл вхолостую.
local function subtreeEnd(block: any, start: number): number
	local finish = start
	if type(block) ~= "table" then return finish end

	if type(block.EndFrame) == "number" then
		finish = math.max(finish, math.floor(block.EndFrame))
	end

	for _, slot in (block.__slots or {}) :: { string } do
		for _, child in slotBlocks(block, slot) do
			finish = math.max(finish, subtreeEnd(child, finish))
		end
	end

	return finish
end

local function timelineEnd(blocks: { any }, parentStart: number): number
	local finish = parentStart

	for _, block in blocks do
		if type(block) ~= "table" then continue end

		local start = parentStart
		if type(block.StartFrame) == "number" then
			start = math.max(parentStart, math.floor(block.StartFrame))
		end
		finish = math.max(finish, start)

		-- `EndFrame` верхнего `Repeat` — тоже граница скилла: без него скилл с
		-- диапазоном 10-90 обрывался бы на `MIN_FRAMES` и диапазон не успевал бы
		-- доиграть.
		if type(block.EndFrame) == "number" then
			finish = math.max(finish, math.floor(block.EndFrame))
		end

		for _, slot in CONTAINER_SLOTS[block.Type] or {} do
			finish = math.max(finish, timelineEnd(slotBlocks(block, slot), start))
		end
	end

	return finish
end

--- Нижняя граница длительности sequence: `MIN_FRAMES`, `Duration` скилла и последний
--- занятый кадр.
---
--- `Duration` здесь именно пол, а не потолок. Обрезать скилл короче последнего шага
--- нельзя: эмиттер тогда напечатает кадр за пределами `Frames`, и `verifyEntries`
--- упадёт с `EMIT_INVARIANT`. Поэтому заданное значение поднимает границу, но не
--- опускает её — так же, как это делает `MIN_FRAMES`.
local function frameFloor(json: any, blocks: { any }): number
	local floor = MIN_FRAMES

	if type(json) == "table" then
		local requested = (json :: any).Duration
		if type(requested) == "number" and requested > floor then floor = requested end
	end

	return math.max(floor, timelineEnd(blocks, 0))
end

--- Есть ли `Repeat` в поддереве. Такой верхнеуровневый блок обязан стать
--- много-кадровым элементом, иначе диапазон исполнился бы один раз.
--- Нужен ли блоку много-кадровый элемент — определяется ТОЛЬКО его собственным типом.
---
--- Раньше здесь был обход поддерева, и это стоило дороже, чем выглядело: вложенный
--- `Repeat` делал много-кадровым весь верхнеуровневый контейнер, внутри которого он
--- нашёлся, а значит `ProcessAttack` с `Repeat` в `OnSuccess` выполнял атаку один раз
--- на каждый кадр диапазона. Теперь вложенный `Repeat` запрещён валидатором (E24), а
--- здесь достаточно прямой проверки: сужение убирает класс ошибок, при котором
--- блок молча исполняется десятки раз.
local function hasRepeat(block: any): boolean
	return type(block) == "table" and block.Type == "Repeat"
end

--- `Preview`: кадры ровно в том порядке, в котором попадут в `Frames`. Терминатор в
--- список не входит — это служебный элемент, а не блок пользователя. `Label` равен
--- `Type`: подпись из `registry` доступна только UI, а эмиттер его не грузит (§10).
local function buildPreview(entries: { Entry }): { any }
	local result: { any } = {}

	for _, entry in entries do
		if entry.Kind == "Terminator" then continue end

		local blocks: { any } = {}
		for _, block in entry.Blocks do
			table.insert(blocks, { Id = block.Id, Type = block.Type, Label = tostring(block.Type) })
		end

		local item: any = { Frame = entry.Frame, Kind = entry.Kind, Blocks = blocks }
		if entry.Kind == "Range" then item.EndFrame = entry.EndFrame end
		table.insert(result, item)
	end

	return result
end

local function buildEntries(
	ctx: Ctx,
	blocks: { any },
	parentStart: number,
	path: { string | number }
): { Entry }
	local singles: { Entry } = {}
	local ranges: { Entry } = {}
	local order: { number } = {}
	local groups: { [number]: { Entry } } = {}
	local scope: Scope = { Target = false, Data = false }

	for index, raw in blocks do
		local blockPath = table.clone(path) :: { string | number }
		table.insert(blockPath, index)

		local block = withSlots(raw, CONTAINER_SLOTS[raw.Type] or {})
		local start = blockStart(ctx, block, blockPath, parentStart)
		local range = hasRepeat(block)

		local entry: Entry = {
			Frame = start,
			Kind = if range then "Range" else "Single",
			Body = emitBlock(ctx, block, blockPath, start, 0, scope),
			Blocks = flattenBlocks(block, {}),
			Empty = false,
			Order = 0,
		}
		if range then entry.EndFrame = math.max(subtreeEnd(block, start), start) end

		if range then
			table.insert(ranges, entry)
		else
			if groups[start] == nil then
				groups[start] = {}
				table.insert(order, start)
			end
			table.insert(groups[start], entry)
		end
	end

	table.sort(order)

	local entries: { Entry } = {}

	-- Одночастотные блоки одного кадра сливаются в один callback: иначе кадр породил
	-- бы столько вызовов, сколько блоков на нём стоит (§7, пункт 4).
	for _, frame in order do
		local body: { string } = {}
		local flattened: { any } = {}

		for _, entry in groups[frame] do
			if #body > 0 then table.insert(body, "") end
			extend(body, entry.Body)
			extend(flattened, entry.Blocks)
		end

		table.insert(entries, {
			Frame = frame,
			Kind = "Single",
			Body = body,
			Blocks = flattened,
			Empty = #body == 0,
			Order = 0,
		})
	end

	for _, entry in ranges do
		table.insert(entries, entry)
	end

	for index, entry in entries do
		entry.Order = index
	end

	-- `table.sort` не стабильный, а кадры с одинаковым номером обязаны остаться в
	-- порядке обхода: иначе `Wait`-подобные маркеры и атаки поменяются местами.
	table.sort(entries, function(a, b)
		if a.Frame == b.Frame then return a.Order < b.Order end
		return a.Frame < b.Frame
	end)

	return entries
end

--- Проверки инвариантов `Sequencer` (§2.2). Они ловят неверный `Frames` на этапе
--- генерации, а не посреди боя: терминатор обязан быть последним, у диапазона
--- `start < end`, и ни один кадр не должен выходить за `maxFrame`.
local function verifyEntries(ctx: Ctx, entries: { Entry }, maxFrame: number)
	if #entries == 0 then
		report(ctx, "EMIT_INVARIANT", "Frames are empty", { "Blocks" })
		return
	end

	for index, entry in entries do
		if entry.Kind == "Terminator" then
			if index ~= #entries then
				report(ctx, "EMIT_INVARIANT", "Terminator is not the last frame", { "Blocks" })
			end
		elseif entry.Empty then
			continue
		elseif entry.Kind == "Range" then
			local finish = entry.EndFrame or entry.Frame
			if finish <= entry.Frame then
				report(
					ctx,
					"EMIT_INVARIANT",
					`Range {num(entry.Frame)}-{num(finish)} is empty`,
					{ "Blocks" }
				)
			elseif finish > maxFrame then
				report(
					ctx,
					"EMIT_INVARIANT",
					`Range ends at {num(finish)}, past maxFrame {num(maxFrame)}`,
					{ "Blocks" }
				)
			end
		elseif entry.Frame > maxFrame then
			report(
				ctx,
				"EMIT_INVARIANT",
				`Frame {num(entry.Frame)} is past maxFrame {num(maxFrame)}`,
				{ "Blocks" }
			)
		end
	end
end

--- Текст массива `Frames`. Преамбула на кадре 0 сбрасывает `seq.Ctx`, иначе повторная
--- активация унаследовала бы цели прошлого броска (§7).
local function framePiece(entry: Entry): { string }
	local args = if entry.Kind == "Range" then "(seq, frame)" else "(seq)"

	local piece: { string } = {
		"\t{",
		`\t\t{num(entry.Frame)},`,
		`\t\tfunction{args}`,
	}
	extend(piece, indented(entry.Body, 3))
	table.insert(piece, "\t\tend,")

	if entry.Kind == "Range" then
		table.insert(piece, `\t\t{num(entry.EndFrame or entry.Frame)},`)
	end
	table.insert(piece, "\t},")

	return piece
end

local function framesLines(entries: { Entry }): { string }
	local lines: { string } = { "Frames = {" }

	-- Преамбула обязательна всегда, даже если на кадре 0 ничего не стоит (§7).
	extend(lines, {
		"\t{",
		"\t\t0,",
		"\t\tfunction(seq)",
		"\t\t\tseq.Ctx = { Targets = {} }",
		"\t\tend,",
		"\t},",
		"",
	})

	for _, entry in entries do
		if entry.Empty then continue end

		if entry.Kind == "Terminator" then
			table.insert(lines, `\t\{ {num(entry.Frame)} \},`)
		else
			extend(lines, framePiece(entry))
			table.insert(lines, "")
		end
	end

	table.insert(lines, "}")
	return lines
end

-- СБОРКА МОДУЛЯ -------------------------------------------------------------

local function requiresLines(ctx: Ctx): { string }
	local lines: { string } = {}

	if ctx.usage.Players then table.insert(lines, `local Players = game:GetService("Players")`) end

	table.insert(lines, `local ReplicatedStorage = game:GetService("ReplicatedStorage")`)
	table.insert(lines, `local ServerScriptService = game:GetService("ServerScriptService")`)
	table.insert(lines, "")
	table.insert(lines, "local Crane = require(ReplicatedStorage.shared.packages.Crane)")

	if ctx.usage.Enums then
		table.insert(lines, "local Enums = require(ServerScriptService.server.Enums)")
	end

	table.insert(lines, "local types = require(ServerScriptService.server.types)")
	return lines
end

--- Локальные ассеты и `self.Assets`. Набор выбирается один раз в `onInit` и больше
--- не пересчитывается: стенд не переключается посреди скилла (§10).
local function assetLines(ctx: Ctx): { string }
	local lines: { string } = {}

	if ctx.usage.Stand then
		extend(lines, {
			"local Stand = StandService:GetStand(self.Character)",
			"local IsStandActive = if Stand then Stand:IsActive() else false",
			"",
			"self.Assets = if IsStandActive then self.Spec.Data.Assets.Stand or self.Spec.Data.Assets",
			"\telse self.Spec.Data.Assets",
		})
	else
		table.insert(lines, "self.Assets = self.Spec.Data.Assets")
	end

	if ctx.usage.Anims then table.insert(lines, "local Anims = self.Assets.Animations") end
	if ctx.usage.Sounds then table.insert(lines, "local Sounds = self.Assets.Sounds") end
	if ctx.usage.Models then table.insert(lines, "local Models = self.Assets.Models") end

	return lines
end

local function moduleLines(ctx: Ctx, json: any, maxFrame: number, entries: { Entry }): { string }
	local displayName = if type(json.DisplayName) == "string"
		then json.DisplayName
		else tostring(json.Id)
	local cooldown = if type(json.Cooldown) == "number" then json.Cooldown else 0

	local tags: { string } = {}
	for _, tag in (json.SkillCharacters or {}) :: { any } do
		if type(tag) == "string" then table.insert(tags, quoted(tag)) end
	end

	local lines: { string } = { "--!native", "--!optimize 2", "" }
	extend(lines, requiresLines(ctx))
	table.insert(lines, "")

	if ctx.usage.Uuid then
		extend(lines, {
			"local Uuid = 0",
			"",
			"local function NextUuid(): number",
			"\tUuid += 1",
			"\treturn Uuid",
			"end",
			"",
		})
	end

	table.insert(lines, "local Skill: types.SkillData = {")
	table.insert(lines, `\tDisplayName = {quoted(displayName)},`)
	table.insert(lines, `\tCooldown = {num(cooldown)},`)
	table.insert(lines, "\tTag = nil,")
	table.insert(lines, "")
	table.insert(lines, `\tSkillCharacters = \{ {table.concat(tags, ", ")} \},`)

	local info = attackInfoLines(ctx, 2)
	if #info > 0 then
		extend(lines, { "", "\tAttackInfo = {" })
		extend(lines, info)
		table.insert(lines, "\t},")
	else
		table.insert(lines, "\tAttackInfo = {},")
	end

	extend(lines, {
		"}",
		"",
		"function Skill:onInit()",
		"\tlocal character = self.Character :: types.Character",
		"\tlocal RootPart = character.RootPart",
		`\tlocal CombatService = Crane:GetService("CombatService")`,
	})

	if ctx.usage.VFXService then
		table.insert(lines, `\tlocal VFXService = Crane:GetService("VFXService")`)
	end
	if ctx.usage.Stand then
		table.insert(lines, `\tlocal StandService = Crane:GetService("StandService")`)
	end

	table.insert(lines, "")
	extend(lines, indented(assetLines(ctx), 1))
	extend(
		lines,
		{ "", "\tself.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {", "" }
	)
	extend(lines, indented(framesLines(entries), 2))
	extend(lines, { "", "\t}))", "end", "" })

	extend(lines, {
		"function Skill:Activate()",
		"\tif self.Sequence then",
		"\t\tself.Sequence:Play()",
		"\t\tself.Sequence:Await()",
		"\tend",
		"end",
		"",
		"function Skill:Interrupt()",
		"\tif self.Sequence then self.Sequence:Stop() end",
		"end",
		"",
		"function Skill:onDestroy()",
		"\tif self.Sequence then self.Sequence:Destroy() end",
		"end",
		"",
		"return Skill",
	})

	return lines
end

-- ТОЧКА ВХОДА ---------------------------------------------------------------

--- Blueprint → модуль скилла.
---
--- `Source` собирается всегда, даже когда `Errors` непуст: сломанный блок
--- выбрасывается, остальные печатаются как обычно, а UI показывает проблемы списком.
--- Вызывающий код решает, что делать с ошибками — блокировать экспорт или нет (§9).
local function makeContext(json: any): Ctx
	local ctx: Ctx = {
		errors = {},
		usage = {
			Anims = false,
			Sounds = false,
			Models = false,
			Enums = false,
			Stand = json.AssetSource == "Stand",
			Players = false,
			Uuid = false,
			VFXService = false,
		},
		counters = {},
		slots = {},
		slotSpeed = {},
		slotFade = {},
		soundSlots = {},
		attackInfo = {},
		handles = {},
	}

	-- `AttackInfo` шапки засевается из скилла раньше, чем будет прочитано хоть одно
	-- свойство блока: `mergeAttackInfo` заполняет только пустые места, поэтому дефолт,
	-- записанный здесь, оказывается базой, а любая атака может перекрыть своё поле.
	-- Порядок важен и потому, что «первое непустое побеждает» — вставка после обхода
	-- дала бы обратный смысл: тогда бы блоки забивали шапку, а скилл ничего не добавлял.
	seedAttackInfoDefaults(ctx, json.AttackInfoDefaults)

	ctx.handles = countHandles(if type(json.Blocks) == "table" then json.Blocks else {})

	for _, slot in (json.AnimationSlots or {}) :: { any } do
		if type(slot) == "table" and type(slot.Id) == "string" then
			ctx.slots[slot.Id] = if type(slot.AnimationId) == "string"
				then slot.AnimationId
				else slot.Id
			if type(slot.Speed) == "number" then ctx.slotSpeed[slot.Id] = slot.Speed end
			if type(slot.FadeTime) == "number" then ctx.slotFade[slot.Id] = slot.FadeTime end
		end
	end

	for _, slot in (json.SoundSlots or {}) :: { any } do
		if type(slot) == "table" and type(slot.Id) == "string" then
			ctx.soundSlots[slot.Id] = if type(slot.SoundId) == "string"
				then slot.SoundId
				else slot.Id
		end
	end

	return ctx
end

local function buildAllEntries(json: any): (Ctx, { Entry }, number)
	local ctx = makeContext(json)
	local blocks = if type(json.Blocks) == "table" then json.Blocks else {}
	local entries = buildEntries(ctx, blocks, 0, { "Blocks" })

	-- `Wait` не печатается, но продлевает скилл, поэтому итоговый кадр считается по
	-- сырому дереву, а не по `Frames`.
	local maxFrameResult = frameFloor(json, blocks)

	table.insert(entries, {
		Frame = maxFrameResult,
		Kind = "Terminator",
		Body = {},
		Blocks = {},
		Empty = false,
		Order = #entries + 1,
	})
	verifyEntries(ctx, entries, maxFrameResult)

	return ctx, entries, maxFrameResult
end

local function maxFrame(json: any): number
	if type(json) ~= "table" then return MIN_FRAMES end
	local blocks = if type(json.Blocks) == "table" then json.Blocks else {}
	return frameFloor(json, blocks)
end

local function framesSource(json: any): string
	if type(json) ~= "table" then
		return "Frames = {\n\t{\n\t\t0,\n\t\tfunction(seq)\n\t\t\tseq.Ctx = { Targets = {} }\n\t\tend,\n\t},\n}"
	end
	local ctx = makeContext(json)
	local blocks = if type(json.Blocks) == "table" then json.Blocks else {}
	local entries = buildEntries(ctx, blocks, 0, { "Blocks" })
	local maxFrameResult = frameFloor(json, blocks)

	table.insert(entries, {
		Frame = maxFrameResult,
		Kind = "Terminator",
		Body = {},
		Blocks = {},
		Empty = false,
		Order = #entries + 1,
	})
	verifyEntries(ctx, entries, maxFrameResult)

	-- Тот же отступ, что и в `moduleLines`: блок должен совпадать с исходником
	-- символ в символ, иначе вкладка Frames покажет не то, что уйдёт в файл.
	return table.concat(indented(framesLines(entries), 2), "\n")
end

local function emit(json: any): { [string]: any }
	if type(json) ~= "table" then
		return {
			Source = "",
			Preview = {},
			Errors = {
				{
					Code = "EMIT_INPUT",
					Message = "Blueprint is not a table",
					Path = {},
				},
			},
		}
	end

	local ctx, entries, maxFrameResult = buildAllEntries(json)

	return {
		Source = table.concat(moduleLines(ctx, json, maxFrameResult, entries), "\n"),
		Preview = buildPreview(entries),
		Errors = ctx.errors,
	}
end

--- Только кадры: `PreviewTab` (§10) и тесты не должны зависеть от текста модуля.
local function preview(json: any): { any }
	return emit(json).Preview
end

return {
	emit = emit,
	preview = preview,
	maxFrame = maxFrame,
	framesSource = framesSource,
	MIN_FRAMES = MIN_FRAMES,
}
