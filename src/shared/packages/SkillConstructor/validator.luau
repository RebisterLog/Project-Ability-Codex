--!strict

--- Валидация blueprint по §9. Модуль не обращается к Roblox-типам на этапе
--- загрузки, поэтому `validateStructural` работает и в CLI на `lune` (§11).
---
--- Коды проблем отображаются на строки таблицы §9:
---
--- | Code | Строка §9 | Что проверяет |
--- |---|---|---|
--- | E1–E17 | 1–17 | один к одному |
--- | E18 | 18 и 19 | значение ∈ `Options` для любого `enum` |
--- | E19 | 20 | `CreateGrab`: `BindMode = "RootToRoot"` требует `Offset` |
--- | E20 | — | значение соответствует объявленному типу свойства |
---
--- Числа 21–27 не перенумеровываются из-за снятой строки 24: блок
--- `PlayDashAnimation` удалён — эффект `Dash` на клиенте выводит направление
--- сам из вектора `Normal` и не даёт выбрать его напрямую, — вместе с ним ушёл
--- и код E24. Дыра в нумерации намеренная: коды уже напечатаны в UI и в отчётах
--- CLI, переименовывать их задним числом хуже, чем оставить пропуск.
---
--- `Repeat` намеренно исключён из E5 и E13: обе ситуации собирает E14 в одно
--- сообщение, иначе сломанный `Repeat` показывал бы пользователю три почти
--- одинаковые ошибки. `EndFrame` по типам разрешён только `Repeat`, так что E5
--- остаётся защитой от мусорного поля у остальных типов.
---
--- Проверки 18 и 19 объединены в E18: обе состоят в том, что значение лежит в
--- `Options`, а этот же код заодно охраняет `BindMode` и `Level`, для которых
--- отдельных строк в §9 нет.
---
--- Наружу три функции, и деление не совпадает с §9 намеренно:
---
--- * `validateStructural(blueprint)` — проверки 1–20 и W1–W6. Roblox-данных не
---   нужно, поэтому работает и в UI, и в CLI;
--- * `validateAgainstSpec(blueprint, specData)` — проверки 21–23, 25–27 и W7. Требует
---   живой `Spec`, зовётся только из `PreviewTab` (§9), а Roblox-модули достаёт
---   лениво, уже внутри функции;
--- * `checkAgainstSpec(blueprint, context)` — те же правила, но с уже готовым
---   контекстом (`specData`, `validTags`). Существует ради тестов: в
---   `lune` `require` не умеет брать модуль по инстансу, поэтому правила не должны
---   быть связаны с тем, кто именно их достал.

--- `registry` — соседний модуль, но в игре он доступен как `script.Parent`, а в
--- `lune` только по пути: у тестов общего назначения нет понятия `ReplicatedStorage`
--- (пакет остаётся environment-agnostic, §3).
local function pickRegistry()
	if game then return script.Parent.registry end
	return "./registry"
end

local registry = require(pickRegistry())

local TAG_KEY = "$"
local VALID_ASSET_SOURCES = { Spec = true, Stand = true }
local ID_PATTERN = "^[%w_]+$"
local WIDE_REPEAT_FRAMES = 30

local function report(
	list: { any },
	code: string,
	message: string,
	path: { string | number },
	blockId: string?,
	property: string?
)
	table.insert(list, {
		Code = code,
		Message = message,
		Path = path,
		BlockId = blockId,
		Property = property,
	})
end

--- Путь вглубь: `{ "Blocks", 1 }` + `"Children"` + слот + индекс → путь до ребёнка.
local function childPath(path: { string | number }, ...): { string | number }
	local result = table.clone(path)
	for _, segment in { ... } do
		table.insert(result, segment)
	end
	return result
end

local function contains(list: any, value: any): boolean
	if type(list) ~= "table" then return false end
	for _, item in list do
		if item == value then return true end
	end
	return false
end

local function hasKey(container: any, key: any): boolean
	return type(container) == "table" and key ~= nil and container[key] ~= nil
end

--- Имя типа значения для сообщений. Тип-tag важнее `typeof`: после `codec.decode`
--- ассет остаётся таблицей, и называть её `table` в ошибке бессмысленно. Вызов
--- `typeof` подстрахован, потому что проверка не имеет права упасть на мусоре —
--- иначе вместо читаемой ошибки пользователь получил бы стектрейс.
local function typeName(value: any): string
	if type(value) == "table" and value[TAG_KEY] ~= nil then return tostring(value[TAG_KEY]) end

	local ok, result = pcall(typeof, value)
	if ok and type(result) == "string" then return result end

	return type(value)
end

--- Тип значения может прийти двумя способами: tagged-таблицей после `codec.decode`
--- либо живым экземпляром, если UI правит blueprint в памяти. Допускаем оба.
local function matchesType(spec: any, value: any): boolean
	if type(spec) == "table" then
		for _, single in spec do
			if matchesType(single, value) then return true end
		end
		return false
	end

	if spec == "enum" then return type(value) == "string" end
	if spec == "number" then return type(value) == "number" end
	if spec == "string" then return type(value) == "string" end
	if spec == "boolean" then return type(value) == "boolean" end

	local actual = typeName(value)
	if spec == "Vector3" then return actual == "V3" or actual == "Vector3" end
	if spec == "CFrame" then return actual == "CF" or actual == "CFrame" end
	if spec == "Color3" then return actual == "C3" or actual == "Color3" end

	return true
end

local function describeType(spec: any): string
	if type(spec) ~= "table" then return tostring(spec) end

	local names = {}
	for _, single in spec do
		table.insert(names, describeType(single))
	end
	return table.concat(names, " or ")
end

--- Все блоки ниже по дереву, а не только прямые дети. Нужно W1 и W2: тело
--- `Repeat` дублируется целиком, поэтому опасный блок опасен на любой глубине.
local function descendants(block: any): { any }
	local result = {}

	local children = block.Children
	if type(children) ~= "table" then return result end

	for _, list in children do
		if type(list) == "table" then
			for _, child in list do
				table.insert(result, child)
				for _, deep in descendants(child) do
					table.insert(result, deep)
				end
			end
		end
	end
	return result
end

--- Есть ли блок этого типа в дереве. Нужна E21: `Hitbox` может лежать внутри
--- `Repeat` или в реакции `ProcessAttack`, но требование `SkillCharacters` одно.
local function hasBlockOfType(blocks: any, blockType: string): boolean
	if type(blocks) ~= "table" then return false end

	for _, block in blocks do
		if type(block) == "table" then
			if block.Type == blockType then return true end

			local children = block.Children
			if type(children) == "table" then
				for _, nested in children do
					if hasBlockOfType(nested, blockType) then return true end
				end
			end
		end
	end

	return false
end

local function validateValue(
	block: any,
	definition: any,
	property: any,
	value: any,
	path: { string | number },
	blockId: string?,
	errors: { any }
)
	local propertyPath = childPath(path, "Properties", property.Name)
	local label = `{definition.Id}.{property.Name}`

	if not matchesType(property.Type, value) then
		report(
			errors,
			"E20",
			`Property {label} must be {describeType(property.Type)}, got {typeName(value)}`,
			propertyPath,
			blockId,
			property.Name
		)
		return
	end

	if property.Options and not contains(property.Options, value) then
		report(
			errors,
			"E18",
			`Unknown value {tostring(value)} for property {label}`,
			propertyPath,
			blockId,
			property.Name
		)
		return
	end

	if type(value) == "number" and (property.Min ~= nil or property.Max ~= nil) then
		if
			(property.Min ~= nil and value < property.Min)
			or (property.Max ~= nil and value > property.Max)
		then
			report(
				errors,
				"E9",
				`Property {label} is out of range [{tostring(property.Min)}, {tostring(property.Max)}]`,
				propertyPath,
				blockId,
				property.Name
			)
		end
	end

	if definition.Id == "SetNoCollision" and property.Name == "State" and value == false then
		report(
			errors,
			"E17",
			"SetNoCollision State=false is not supported (bug in Watchers.luau:68)",
			propertyPath,
			blockId,
			property.Name
		)
	end

	if definition.Id == "CreateGrab" and property.Name == "BindMode" and value == "RootToRoot" then
		if block.Properties.Offset == nil then
			report(
				errors,
				"E19",
				"CreateGrab with BindMode=RootToRoot requires an explicit Offset",
				propertyPath,
				blockId,
				property.Name
			)
		end
	end

	if definition.Id == "Hitbox" and property.Name == "Size" then
		-- Форму задаёт тип `Size`, а `Shape` только описывает её в UI. Если они
		-- расходятся, скилл не падает и не выглядит сломанным — он просто получается
		-- не той формы, которую показал интерфейс: `Ball` с `Vector3` молча остаётся
		-- кубом. Объединение типов само по себе это не ловит, поэтому сверка явная.
		local properties = block.Properties
		local shape = if type(properties) == "table" then properties.Shape else nil
		local wantsNumber = shape == "Ball"

		if shape ~= nil and wantsNumber ~= (type(value) == "number") then
			report(
				errors,
				"E28",
				`Hitbox Shape={shape} needs Size of type {if wantsNumber
					then "number"
					else "Vector3"}, got {type(value)}`,
				propertyPath,
				blockId,
				property.Name
			)
		end
	end

	local rawField = if definition.Id == "Branch" then "Condition" else nil
	if definition.Id == "CustomCallback" then rawField = "Code" end
	if rawField ~= nil and property.Name == rawField then
		if type(value) == "string" and value:match("^%s*$") ~= nil then
			local code = if definition.Id == "Branch" then "E15" else "E16"
			local subject = if definition.Id == "Branch" then "condition" else "code"
			report(
				errors,
				code,
				`Empty {subject} in block {definition.Id}`,
				propertyPath,
				blockId,
				property.Name
			)
		end
	end
end

--- JSON-форма (§8) и Lua-форма хранят секции вложенными таблицами (`Stun = { Duration = ... }`),
--- а реестр описывает те же свойства плоскими именами (`Stun.Duration`). Значения-дататайпы
--- помечены тегом, поэтому любая непустая таблица под ключом `Properties` — это секция.
--- Разворачиваем вложенность один раз, чтобы все три проверки ниже видели одинаковый вид.
local function flattenProperties(properties: any): { [string]: any }
	local flat: { [string]: any } = {}

	for key, value in properties do
		local name = tostring(key)

		if type(value) == "table" and value[TAG_KEY] == nil then
			for childKey, childValue in value do
				flat[`{name}.{tostring(childKey)}`] = childValue
			end
		else
			flat[name] = value
		end
	end

	return flat
end

local function validateProperties(
	block: any,
	definition: any,
	blockId: string?,
	path: { string | number },
	errors: { any }
)
	local rawProperties = block.Properties
	if type(rawProperties) ~= "table" then return end

	local properties = flattenProperties(rawProperties)

	for key in properties do
		if registry.getProperty(definition.Id, tostring(key)) == nil then
			report(
				errors,
				"E7",
				`Unknown property {tostring(key)} in block {definition.Id}`,
				childPath(path, "Properties", tostring(key)),
				blockId,
				tostring(key)
			)
		end
	end

	for _, property in definition.Properties do
		if property.Required and properties[property.Name] == nil and property.Default == nil then
			report(
				errors,
				"E8",
				`Property {property.Name} is not set in block {definition.Id}`,
				childPath(path, "Properties", property.Name),
				blockId,
				property.Name
			)
		end
	end

	for _, property in definition.Properties do
		local value = properties[property.Name]
		if value ~= nil then
			validateValue(block, definition, property, value, path, blockId, errors)
		end
	end
end

local function validateSlots(
	block: any,
	definition: any,
	blockId: string?,
	path: { string | number },
	errors: { any }
)
	local children = block.Children
	local slots = definition.ChildrenSlots

	if type(children) == "table" then
		for slot in children do
			if slots == nil then
				report(
					errors,
					"E11",
					`Block {definition.Id} does not support nesting`,
					childPath(path, "Children", tostring(slot)),
					blockId
				)
				break
			elseif not contains(slots, tostring(slot)) then
				report(
					errors,
					"E12",
					`Slot {tostring(slot)} does not exist for block {definition.Id}`,
					childPath(path, "Children", tostring(slot)),
					blockId
				)
			end
		end
	end

	if definition.Id == "Repeat" then
		local problems = {}

		local body = if type(children) == "table" then children.Body else nil
		if type(body) ~= "table" or #body == 0 then table.insert(problems, "no body") end

		if
			type(block.EndFrame) ~= "number"
			or type(block.StartFrame) ~= "number"
			or block.EndFrame <= block.StartFrame
		then
			table.insert(problems, "EndFrame must be greater than StartFrame")
		end

		if #problems > 0 then
			report(
				errors,
				"E14",
				`Repeat is not usable: {table.concat(problems, "; ")}`,
				path,
				blockId
			)
		end
		return
	end

	local required = definition.RequiredSlots
	if required ~= nil then
		local missing = {}
		for _, slot in required do
			local list = if type(children) == "table" then children[slot] else nil
			if type(list) ~= "table" or #list == 0 then table.insert(missing, slot) end
		end

		if #missing > 0 then
			report(
				errors,
				"E13",
				`{definition.Id} has no filled slots: {table.concat(missing, ", ")}`,
				path,
				blockId
			)
		end
	end
end

local function collectWarnings(
	block: any,
	definition: any,
	parentType: string?,
	path: { string | number },
	blockId: string?,
	warnings: { any }
)
	local blockType = block.Type
	local properties = block.Properties

	if type(properties) == "table" then
		local raw = if blockType == "Branch" then properties.Condition else nil
		if blockType == "CustomCallback" then raw = properties.Code end

		if type(raw) == "string" and raw:match("%S") ~= nil then
			report(
				warnings,
				"W5",
				"Raw Luau will be copied into the generated file verbatim",
				path,
				blockId
			)
		end
	end

	if definition == nil then return end

	if definition.Id == "Repeat" then
		local nested = descendants(block)

		for _, child in nested do
			if type(child) == "table" and child.Type == "ProcessAttack" then
				report(
					warnings,
					"W1",
					"Repeat contains ProcessAttack: the body runs several times per frame",
					path,
					blockId
				)
				break
			end
		end

		if type(block.StartFrame) == "number" and type(block.EndFrame) == "number" then
			local width = block.EndFrame - block.StartFrame
			if width > WIDE_REPEAT_FRAMES then
				report(
					warnings,
					"W4",
					`Repeat spans {width} frames, more than {WIDE_REPEAT_FRAMES}`,
					path,
					blockId
				)
			end
		end
	end

	if parentType == "ProcessAttack" and definition.Id == "Branch" then
		report(
			warnings,
			"W3",
			"Branch inside ProcessAttack: order relative to Cast is not guaranteed",
			path,
			blockId
		)
	end

	if definition.Id == "ProcessAttack" then
		local filled = false
		-- Секция `Block` приходит и плоской (`Block.Blockable`), и вложенной
		-- (`Block = { Blockable = ... }`), поэтому смотрим на развёрнутый вид.
		if type(properties) == "table" then
			for key in flattenProperties(properties) do
				if type(key) == "string" and key:sub(1, 6) == "Block." then
					filled = true
					break
				end
			end
		end

		if not filled then
			report(
				warnings,
				"W6",
				"ProcessAttack without Block falls back to the hidden default in Hooks/Block.luau",
				path,
				blockId
			)
		end
	end
end

--- Слот: `PlayAnimation` / `StopAnimation` берут его из `AnimationSlots`, а
--- `PlaySound` / `StopSound` — из `SoundSlots`. Реестр говорит, откуда, через
--- `definition.SlotSource`; без этого проверка шла бы по «анимационному» индексу и
--- ругалась бы на любой корректный звуковой слот.
---
--- Плюс правило «ровно одно из двух» для звуковых блоков. `Slot` дополнил прямую
--- ссылку `Sound`, и та осталась поддержанной для файлов версии 1, поэтому оба поля
--- объявлены опциональными и решение принимает здесь, а не флагом `Required`:
--- обязательный `Slot` запретил бы старый путь наравне с новым.
---
--- Оба заполнены — ошибка, потому что полученный ассет зависел бы от порядка чтения.
--- Не заполнено ни одно — тоже ошибка: блок не значил бы ничего, и `PlaySound` без
--- звука тихо ничего не издал бы.
local function validateSlotReference(
	block: any,
	definition: any,
	slots: { [string]: string },
	blockId: string?,
	path: { string | number },
	errors: { any }
)
	if registry.getProperty(definition.Id, "Slot") == nil then return end

	local properties = block.Properties
	if type(properties) ~= "table" then return end

	local slotValue = properties.Slot
	local hasSlot = type(slotValue) == "string" and slotValue ~= ""

	if hasSlot and slots[slotValue] == nil then
		report(
			errors,
			"E10",
			`Slot {slotValue} not found`,
			childPath(path, "Properties", "Slot"),
			blockId,
			"Slot"
		)
	end

	-- Прямая ссылка есть только у звуковых блоков. У анимационных её нет вовсе, и
	-- сравнивать нечего — правило «одно из двух» к ним не относится.
	if definition.SlotSource ~= "Sound" then return end

	local sound = properties.Sound
	local hasSound = type(sound) == "string" and sound ~= ""

	if hasSlot and hasSound then
		report(
			errors,
			"E2",
			`Both Slot and Sound are set: pick one`,
			childPath(path, "Properties", "Slot"),
			blockId,
			"Slot"
		)
	elseif not hasSlot and not hasSound then
		report(
			errors,
			"E8",
			`{definition.Id} needs either a Slot or a Sound`,
			childPath(path, "Properties"),
			blockId,
			"Slot"
		)
	end
end

local function validateBlock(
	block: any,
	path: { string | number },
	parentType: string?,
	slots: { [string]: string },
	soundSlots: { [string]: string },
	errors: { any },
	warnings: { any }
)
	if type(block) ~= "table" then return end

	local blockId = if type(block.Id) == "string" then block.Id else nil
	local blockType = if type(block.Type) == "string" then block.Type else nil
	local definition = if blockType ~= nil then registry.get(blockType) else nil

	if type(block.StartFrame) ~= "number" or block.StartFrame < 0 or block.StartFrame % 1 ~= 0 then
		report(
			errors,
			"E4",
			`Invalid StartFrame in block {blockId or "?"}: {tostring(block.StartFrame)}`,
			path,
			blockId
		)
	end

	if definition == nil then
		report(errors, "E6", `Unknown block type: {tostring(block.Type)}`, path, blockId)
	else
		if definition.Id ~= "Repeat" and block.EndFrame ~= nil then
			local endFrame = block.EndFrame
			local startFrame = if type(block.StartFrame) == "number" then block.StartFrame else 0
			if type(endFrame) ~= "number" or endFrame <= startFrame then
				report(
					errors,
					"E5",
					`EndFrame <= StartFrame in block {blockId or "?"}`,
					childPath(path, "EndFrame"),
					blockId
				)
			end
		end

		-- `Repeat` нельзя вкладывать: эмиттер выражает «каждый кадр диапазона» тем, что
		-- делает много-кадровым элементом весь верхнеуровневый блок, внутри которого
		-- встретился `Repeat` (`emitter.luau`, `hasRepeat`). Для верхнего `Repeat` это
		-- верно, но для контейнера вроде `ProcessAttack` означает, что атака выполнится
		-- один раз на КАЖДЫЙ кадр диапазона — 90 атак вместо одной, молча и без
		-- предупреждения. Плоский `Sequencer` не умеет вложенные диапазоны, поэтому
		-- запрет здесь честнее, чем молчаливое умножение урона.
		if blockType == "Repeat" and parentType ~= nil then
			report(
				errors,
				"E24",
				`Repeat cannot be nested inside {parentType}: it repeats every frame of the sequence, so the whole {parentType} would run once per frame`,
				path,
				blockId
			)
		end

		validateProperties(block, definition, blockId, path, errors)
		validateSlotReference(
			block,
			definition,
			if definition.SlotSource == "Sound" then soundSlots else slots,
			blockId,
			path,
			errors
		)
		validateSlots(block, definition, blockId, path, errors)
	end

	collectWarnings(block, definition, parentType, path, blockId, warnings)

	local children = block.Children
	if type(children) == "table" then
		for slot, list in children do
			if type(list) == "table" then
				for index, child in list do
					validateBlock(
						child,
						childPath(path, "Children", tostring(slot), index),
						blockType,
						slots,
						soundSlots,
						errors,
						warnings
					)
				end
			end
		end
	end
end

--- Индекс слотов одного вида: GUID → ключ ассета. `AnimationSlots` и `SoundSlots`
--- используют один и тот же приём, поле с ключом отличается именем.
local function slotIndexOf(slots: any, keyField: string): { [string]: string }
	local result: { [string]: string } = {}

	if type(slots) ~= "table" then return result end

	for _, slot in slots do
		if type(slot) == "table" and type(slot.Id) == "string" then
			result[slot.Id] = if type(slot[keyField]) == "string" then slot[keyField] else ""
		end
	end
	return result
end

local function slotIndex(blueprint: any): { [string]: string }
	return slotIndexOf(blueprint.AnimationSlots, "AnimationId")
end

local function soundSlotIndex(blueprint: any): { [string]: string }
	return slotIndexOf(blueprint.SoundSlots, "SoundId")
end

--- Проверки 1–20 и предупреждения W1–W6. Roblox-данных не требует, поэтому
--- вызывается и в UI, и в CLI (§9, §11). Никогда не бросает исключение: на вход
--- приходит пользовательский JSON, любой мусор обязан стать записью в `errors`.
local function validateStructural(blueprint: any): { [string]: any }
	local errors: { any } = {}
	local warnings: { any } = {}

	if type(blueprint) ~= "table" then
		report(errors, "E1", "Skill blueprint must be a table", {})
		return { errors = errors, warnings = warnings }
	end

	local id = blueprint.Id
	if type(id) ~= "string" or id:match(ID_PATTERN) == nil then
		report(
			errors,
			"E1",
			`Skill Id must be an identifier ([A-Za-z0-9_]+), got {tostring(id)}`,
			{ "Id" }
		)
	end

	if type(blueprint.Cooldown) ~= "number" or blueprint.Cooldown < 0 then
		report(
			errors,
			"E2",
			`Cooldown must be a non-negative number, got {tostring(blueprint.Cooldown)}`,
			{ "Cooldown" }
		)
	end

	-- `Duration` опционален, но если он есть, обязан быть числом не меньше нуля.
	-- Иначе эмиттер молча заменил бы его пол в `frameFloor`, и скилл получился бы
	-- длиннее, чем намеревался пользователь, без всякой видимой причины.
	if
		blueprint.Duration ~= nil
		and (type(blueprint.Duration) ~= "number" or blueprint.Duration < 0)
	then
		report(
			errors,
			"E2",
			`Duration must be a non-negative number, got {tostring(blueprint.Duration)}`,
			{ "Duration" }
		)
	end

	-- `AttackInfoDefaults` необязателен, но обязан быть таблицей. Неключевые значения-
	-- примитивы не эмитятся: `isPrintable` отсекает их, и скилл молча потерял бы общий
	-- дефолт секции, которая так и не появилась бы в шапке.
	if blueprint.AttackInfoDefaults ~= nil and type(blueprint.AttackInfoDefaults) ~= "table" then
		report(
			errors,
			"E2",
			`AttackInfoDefaults must be a table, got {type(blueprint.AttackInfoDefaults)}`,
			{ "AttackInfoDefaults" }
		)
	end

	if
		type(blueprint.AssetSource) ~= "string" or not VALID_ASSET_SOURCES[blueprint.AssetSource]
	then
		report(
			errors,
			"E3",
			`Unknown AssetSource: {tostring(blueprint.AssetSource)}`,
			{ "AssetSource" }
		)
	end

	local slots = slotIndex(blueprint)
	local soundSlots = soundSlotIndex(blueprint)
	local blocks = blueprint.Blocks
	if type(blocks) == "table" then
		for index, block in blocks do
			validateBlock(block, { "Blocks", index }, nil, slots, soundSlots, errors, warnings)
		end
	end

	return { errors = errors, warnings = warnings }
end

--- Ассеты, которые увидит сгенерированный скилл. При `Stand` это `Assets.Stand`,
--- но если его нет, проверки 23/25/26 продолжают смотреть на базовые ассеты:
--- иначе одна поломка превратилась бы в десяток E23, а W7 уже объясняет причину.
local function effectiveAssets(blueprint: any, specData: any): any?
	if type(specData) ~= "table" or type(specData.Assets) ~= "table" then return nil end

	local assets = specData.Assets
	if blueprint.AssetSource == "Stand" and type(assets.Stand) == "table" then
		return assets.Stand
	end
	return assets
end

--- Проверки 21–27 и предупреждение W7 в чистом виде: всё необходимое уже
--- передано в `context`. Отделена от `validateAgainstSpec` намеренно — правила
--- не должны зависеть от Roblox-глобалов, иначе их нельзя проверить в `lune`
--- с фикстурами, а в игре проверка шла бы по настоящему `Spec.Data`.
---
--- `context.specData` — `Spec.Data`, `context.validTags` — `bot-characters.SkillCharacters`.
local function checkAgainstSpec(
	blueprint: any,
	context: { specData: any, validTags: any }
): { [string]: any }
	local errors: { any } = {}
	local warnings: { any } = {}

	if type(blueprint) ~= "table" then return { errors = errors, warnings = warnings } end

	local specData = context.specData
	local validTags = context.validTags

	local tags = blueprint.SkillCharacters
	if type(tags) ~= "table" then tags = {} end

	if #tags == 0 and hasBlockOfType(blueprint.Blocks, "Hitbox") then
		report(
			errors,
			"E21",
			"Hitbox without SkillCharacters: BotService will fail at Bot.luau:198",
			{ "SkillCharacters" }
		)
	end

	for index, tag in tags do
		if not hasKey(validTags, tag) then
			report(
				errors,
				"E22",
				`Unknown skill character tag: {tostring(tag)}`,
				{ "SkillCharacters", index }
			)
		end
	end

	local assets = effectiveAssets(blueprint, specData)
	local animations = if type(assets) == "table" then assets.Animations else nil
	local sounds = if type(assets) == "table" then assets.Sounds else nil
	local models = if type(assets) == "table" then assets.Models else nil

	local slots = slotIndex(blueprint)
	local soundSlots = soundSlotIndex(blueprint)

	--- Путь передаётся вниз, а не собирается из `BlockId`: UI подсвечивает узел по
	--- индексу в `Blocks`, и тот же путь печатает CLI (§9).
	local function visit(block: any, path: { string | number })
		if type(block) ~= "table" then return end

		local blockType = block.Type
		local blockId = if type(block.Id) == "string" then block.Id else nil
		local definition = if type(blockType) == "string" then registry.get(blockType) else nil
		local properties = block.Properties

		if definition ~= nil and type(properties) == "table" then
			-- Анимация: ключ либо из слота, либо из прямой ссылки. Проверяетсяраз на блок.
			if blockType == "PlayAnimation" or blockType == "StopAnimation" then
				local key = if type(properties.Slot) == "string"
					then slots[properties.Slot]
					else nil

				if key ~= nil and key ~= "" and not hasKey(animations, key) then
					report(
						errors,
						"E23",
						`Animation {key} not found in Assets.Animations`,
						childPath(path, "Properties", "Slot"),
						blockId,
						"Slot"
					)
				end
			end

			-- Звук: тот же приём. `Slot` берётся из `SoundSlots`, прямой путь — из
			-- свойства `Sound` (версия 1). Оба блока (`PlaySound` и `StopSound`)
			-- покрываются одной проверкой.
			if blockType == "PlaySound" or blockType == "StopSound" then
				local usesSlot = type(properties.Slot) == "string"
				local key = if usesSlot then soundSlots[properties.Slot] else properties.Sound

				if type(key) == "string" and key ~= "" and not hasKey(sounds, key) then
					local property = if usesSlot then "Slot" else "Sound"
					report(
						errors,
						"E25",
						`Sound {key} not found in Assets.Sounds`,
						childPath(path, "Properties", property),
						blockId,
						property
					)
				end
			end

			if blockType == "EmitParticle" and type(properties.Particle) == "string" then
				if not hasKey(models, properties.Particle) then
					report(
						errors,
						"E26",
						`Model {properties.Particle} not found in Assets.Models`,
						childPath(path, "Properties", "Particle"),
						blockId,
						"Particle"
					)
				end
			end

			if blockType == "EmitFolder" and type(properties.Folder) == "string" then
				if not hasKey(models, properties.Folder) then
					report(
						errors,
						"E27",
						`Folder {properties.Folder} not found in Assets.Models`,
						childPath(path, "Properties", "Folder"),
						blockId,
						"Folder"
					)
				end
			end
		end

		local children = block.Children
		if type(children) == "table" then
			for slot, list in children do
				if type(list) == "table" then
					for index, child in list do
						visit(child, childPath(path, "Children", tostring(slot), index))
					end
				end
			end
		end
	end

	local blocks = blueprint.Blocks
	if type(blocks) == "table" then
		for index, block in blocks do
			visit(block, { "Blocks", index })
		end
	end

	--- W7 ловит только отсутствие `Assets.Stand` — ровно тот случай, когда
	--- `Punch.luau:37` упадёт. Если таблица есть, но в ней не хватает ключа,
	--- этот ключ уже не найден в E23/E25/E26/E27: дублировать ту же мысль
	--- вторым кодом незачем.
	if blueprint.AssetSource == "Stand" then
		local stand = if type(specData) == "table" and type(specData.Assets) == "table"
			then specData.Assets.Stand
			else nil

		if type(stand) ~= "table" then
			report(
				warnings,
				"W7",
				"AssetSource is Stand but Spec.Data.Assets.Stand is missing: Punch.luau:37 will fail",
				{ "AssetSource" }
			)
		end
	end

	return { errors = errors, warnings = warnings }
end

--- Обёртка над `checkAgainstSpec`: достаёт из игры то, что нужно правилам, и вызывает
--- их. Требует живой `Spec`, поэтому зовётся только из `PreviewTab` (§9). Roblox-модули
--- требуются лениво, внутри функции: CLI её не зовёт, а при загрузке модуля они не
--- нужны, иначе `lune` не смог бы импортировать `validator` вовсе.
local function validateAgainstSpec(blueprint: any, specData: any): { [string]: any }
	if type(blueprint) ~= "table" then return { errors = {}, warnings = {} } end

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local botCharacters = require(ReplicatedStorage.shared["bot-characters"])

	return checkAgainstSpec(blueprint, {
		specData = specData,
		validTags = botCharacters.SkillCharacters,
	})
end

return {
	validateStructural = validateStructural,
	validateAgainstSpec = validateAgainstSpec,
	checkAgainstSpec = checkAgainstSpec,
}
