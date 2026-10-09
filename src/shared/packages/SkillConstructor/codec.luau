--!strict

--- Версия формата blueprint.
---
--- Поднята до 2 вместе с `Duration`, `AttackInfoDefaults` и `SoundSlots`. Все три поля
--- добавлены одним проходом намеренно: `decode` собирает результат из фиксированного
--- списка ключей и **молча выбрасывает** всё, чего в списке нет, поэтому формат,
--- меняющийся дважды подряд, потребовал бы двух миграций вместо одной.
local CURRENT_VERSION = 2
local TAG_KEY = "$"

local V3_KEYS = { "x", "y", "z" } :: { string }
local CF_KEYS = { "px", "py", "pz", "rx", "ry", "rz" } :: { string }
local C3_KEYS = { "r", "g", "b" } :: { string }

local function taggedKeys(tag: string): { string }
	if tag == "V3" then
		return V3_KEYS
	elseif tag == "CF" then
		return CF_KEYS
	elseif tag == "C3" then
		return C3_KEYS
	end
	return {}
end

--- `Stun.Duration` → `Stun`, `Duration`; у корневого ключа группа равна `nil`.
local function splitKey(key: string): (string?, string)
	local dot = string.find(key, ".", 1, true)
	if not dot then return nil, key end
	return string.sub(key, 1, dot - 1), string.sub(key, dot + 1)
end

--- Приводит `Vector3` / `CFrame` / `Color3` к type-tag форме (§8) и заполняет
--- недостающие компоненты нулями. Всё остальное проходит без изменений, поэтому
--- модуль остаётся пригодным для `lune`, где таких типов нет вовсе.
---
--- Типы опознаются через `typeof`, а не по имени класса: в `lune` `typeof` вернёт
--- `"table"` и значение уйдёт дальше нетронутым.
local function toTagged(value: any): any
	local valueType = typeof(value)

	local result: { [string]: any }
	if valueType == "Vector3" then
		result = { [TAG_KEY] = "V3", x = value.X, y = value.Y, z = value.Z }
	elseif valueType == "CFrame" then
		-- Позиция — это свойство `Position`, метода `:Position()` у CFrame нет.
		-- `ToOrientation()` возвращает три отдельных числа в порядке YXZ, а не
		-- Vector3, поэтому углы разворачиваются в три переменные.
		local position = value.Position
		local rx, ry, rz = value:ToOrientation()
		result = {
			[TAG_KEY] = "CF",
			px = position.X,
			py = position.Y,
			pz = position.Z,
			rx = rx,
			ry = ry,
			rz = rz,
		}
	elseif valueType == "Color3" then
		result = { [TAG_KEY] = "C3", r = value.R, g = value.G, b = value.B }
	else
		return value
	end

	for _, key in taggedKeys(result[TAG_KEY]) do
		result[key] = result[key] or 0
	end
	return result
end

--- Обратное преобразование в Roblox-типы. В `lune` не выполняется: весь pipeline
--- (CLI, эмиттер) работает поверх JSON-формы и до Roblox-типов не доходит (§3),
--- поэтому там tagged-объекты остаются объектами.
local function fromTagged(value: any): any
	if type(value) ~= "table" or type(value[TAG_KEY]) ~= "string" then return value end

	local tag = value[TAG_KEY]
	if not game then
		return value
	elseif tag == "V3" then
		return Vector3.new(value.x or 0, value.y or 0, value.z or 0)
	elseif tag == "CF" then
		-- `CFrame.new(px, py, pz, rx, ry, rz)` из ТЗ §8 не существует: у
		-- конструктора нет перегрузки на шесть чисел, и такой вызов падает с
		-- "Invalid number of arguments: 6". Позиция и поворот собираются
		-- умножением, а порядок углов обязан быть YXZ, потому что
		-- `ToOrientation()` — это синоним `ToEulerAnglesYXZ()`; с XYZ
		-- не-YXZ CFrame round-trip не сойдётся.
		return CFrame.new(value.px or 0, value.py or 0, value.pz or 0)
			* CFrame.fromEulerAnglesYXZ(value.rx or 0, value.ry or 0, value.rz or 0)
	elseif tag == "C3" then
		return Color3.fromRGB(
			math.round((value.r or 0) * 255),
			math.round((value.g or 0) * 255),
			math.round((value.b or 0) * 255)
		)
	end
	return value
end

--- Заполняет нулями компоненты tagged-объекта, пришедшие из вручную написанного
--- JSON: `{ "$": "V3" }` без координат должен стать `{ x = 0, y = 0, z = 0 }`,
--- иначе эмиттер напечатает `Vector3.new(nil, nil, nil)`.
local function normalizeTagged(value: any): any
	if type(value) ~= "table" or type(value[TAG_KEY]) ~= "string" then return value end

	local result = { [TAG_KEY] = value[TAG_KEY] }
	for _, key in taggedKeys(value[TAG_KEY]) do
		local component = value[key]
		result[key] = if type(component) == "number" then component else 0
	end
	return result
end

local function asArray(value: any): { [any]: any }
	if type(value) ~= "table" then return {} end
	return value
end

local function isPlainObject(value: any): boolean
	return type(value) == "table" and type(value[TAG_KEY]) ~= "string"
end

--- Раскрывает плоские `Properties` в вложенный вид: `{ ["Stun.Duration"] = 0.7 }`
--- → `{ Stun = { Duration = 0.7 } }`. Ключи без точки остаются на своём месте.
local function encodeProperties(properties: any): { [string]: any }
	local result: { [string]: any } = {}
	if type(properties) ~= "table" then return result end

	for key, value in properties do
		local name = tostring(key)
		local group, field = splitKey(name)

		local bucket = result
		if group then
			if not isPlainObject(result[group]) then result[group] = {} end
			bucket = result[group]
		end

		local prepared = normalizeTagged(toTagged(value))
		if prepared ~= nil then bucket[field] = prepared end
	end
	return result
end

--- Принимает и вложенный вид из §8, и плоский — так открываются файлы,
--- отредактированные руками. Возвращает всегда плоские dotted-ключи, потому что
--- дальше с ними работают реестр, валидатор, эмиттер и UI.
local function decodeProperties(properties: any): { [string]: any }
	local result: { [string]: any } = {}
	if type(properties) ~= "table" then return result end

	for key, value in properties do
		local name = tostring(key)

		if isPlainObject(value) then
			for field, nested in value do
				result[`{name}.{tostring(field)}`] = normalizeTagged(toTagged(nested))
			end
		else
			result[name] = normalizeTagged(toTagged(value))
		end
	end
	return result
end

local function encodeSlot(slot: any): { [string]: any }
	local result: { [string]: any } = {}
	if type(slot) ~= "table" then return result end

	for key, value in slot do
		if value ~= nil then result[tostring(key)] = normalizeTagged(toTagged(value)) end
	end
	return result
end

local function decodeSlot(slot: any): { [string]: any }
	local result: { [string]: any } = {}
	if type(slot) ~= "table" then return result end

	for key, value in slot do
		result[tostring(key)] = normalizeTagged(toTagged(value))
	end
	return result
end

local encodeBlock: (any) -> { [string]: any }
local decodeBlock: (any) -> { [string]: any }

local function encodeChildren(children: any): { [string]: any }?
	if type(children) ~= "table" then return nil end

	local result: { [string]: any } = {}
	for slot, blocks in children do
		if type(blocks) == "table" then
			local encoded = {}
			for index, block in blocks do
				encoded[index] = encodeBlock(block)
			end
			result[tostring(slot)] = encoded
		end
	end
	return if next(result) == nil then nil else result
end

local function decodeChildren(children: any): { [string]: any }?
	if type(children) ~= "table" then return nil end

	local result: { [string]: any } = {}
	for slot, blocks in children do
		if type(blocks) == "table" then
			local decoded = {}
			for index, block in blocks do
				decoded[index] = decodeBlock(block)
			end
			result[tostring(slot)] = decoded
		end
	end
	return if next(result) == nil then nil else result
end

function encodeBlock(block: any): { [string]: any }
	local result: { [string]: any } = {
		Id = block.Id,
		Type = block.Type,
		StartFrame = block.StartFrame,
		Properties = encodeProperties(block.Properties),
	}
	if block.EndFrame ~= nil then result.EndFrame = block.EndFrame end

	local children = encodeChildren(block.Children)
	if children then result.Children = children end
	return result
end

function decodeBlock(block: any): { [string]: any }
	return {
		Id = block.Id,
		Type = block.Type,
		StartFrame = block.StartFrame,
		EndFrame = block.EndFrame,
		Properties = decodeProperties(block.Properties),
		Children = decodeChildren(block.Children),
	}
end

--- Раскрывает blueprint в JSON-форму: плоские свойства становятся вложенными,
--- Roblox-типы — tagged-объектами. Эмиттер принимает ровно этот результат (§3).
---
--- `nil`-поля не пишутся: в JSON они всё равно стали бы `null`, а §8 приравнивает
--- `null` к отсутствующему ключу, то есть к «не задано».
local function encode(blueprint: any): { [string]: any }
	if type(blueprint) ~= "table" then
		error("[SkillConstructor] encode expects a blueprint table", 2)
	end

	local metadata = if type(blueprint.Metadata) == "table" then blueprint.Metadata else {}
	local slots = {}
	for index, slot in asArray(blueprint.AnimationSlots) do
		slots[index] = encodeSlot(slot)
	end

	local soundSlots = {}
	for index, slot in asArray(blueprint.SoundSlots) do
		soundSlots[index] = encodeSlot(slot)
	end

	local blocks = {}
	for index, block in asArray(blueprint.Blocks) do
		blocks[index] = encodeBlock(block)
	end

	local result: { [string]: any } = {
		Id = blueprint.Id,
		DisplayName = blueprint.DisplayName,
		Cooldown = blueprint.Cooldown,
		AssetSource = blueprint.AssetSource,
		SkillCharacters = blueprint.SkillCharacters or {},
		AnimationSlots = slots,
		SoundSlots = soundSlots,
		Blocks = blocks,
		Metadata = {
			CreatedAt = metadata.CreatedAt or 0,
			UpdatedAt = metadata.UpdatedAt or 0,
			Version = metadata.Version or CURRENT_VERSION,
		},
	}

	-- Пишутся только когда заданы. §8 приравнивает отсутствующий ключ к `null`, а
	-- §8 же требует, чтобы «не задано» выглядело одинаково в файле и в памяти, поэтому
	-- пустой `Duration` в JSON был бы неотличим от нулевого — а это разные вещи:
	-- ноль это «длительность ровно ноль», отсутствие это «не задано».
	if type(blueprint.Duration) == "number" then result.Duration = blueprint.Duration end

	if type(blueprint.AttackInfoDefaults) == "table" then
		local defaults: { [string]: any } = {}
		for key, value in blueprint.AttackInfoDefaults do
			defaults[tostring(key)] = normalizeTagged(toTagged(value))
		end
		result.AttackInfoDefaults = defaults
	end

	return result
end

--- Разворачивает JSON-форму в blueprint с плоскими dotted-ключами.
---
--- Отказывается принимать `Metadata.Version` новее известной: файл из будущей версии
--- UI почти наверняка содержит поля, которые этот код потеряет молча, и пользователь
--- получит скилл без части эффектов вместо внятной ошибки (§8).
local function decode(data: any): { [string]: any }
	if type(data) ~= "table" then
		error("[SkillConstructor] file does not contain a JSON object", 2)
	end

	local metadata = if type(data.Metadata) == "table" then data.Metadata else {}
	local version = metadata.Version
	if type(version) == "number" and version > CURRENT_VERSION then
		error(
			`[SkillConstructor] file version {version} is newer than the supported version {CURRENT_VERSION}`,
			2
		)
	end

	local slots = {}
	for index, slot in asArray(data.AnimationSlots) do
		slots[index] = decodeSlot(slot)
	end

	local soundSlots = {}
	for index, slot in asArray(data.SoundSlots) do
		soundSlots[index] = decodeSlot(slot)
	end

	local blocks = {}
	for index, block in asArray(data.Blocks) do
		blocks[index] = decodeBlock(block)
	end

	local result: { [string]: any } = {
		Id = data.Id,
		DisplayName = data.DisplayName,
		Cooldown = data.Cooldown,
		AssetSource = data.AssetSource,
		SkillCharacters = data.SkillCharacters or {},
		AnimationSlots = slots,
		SoundSlots = soundSlots,
		Blocks = blocks,
		Metadata = {
			CreatedAt = metadata.CreatedAt or 0,
			UpdatedAt = metadata.UpdatedAt or 0,
			Version = version or CURRENT_VERSION,
		},
	}

	-- Поля версии 2. Файл версии 1 их не содержит, и это нормально: отсутствие здесь
	-- означает «не задано», а не «потеряно» — расхождение было бы только если бы поле
	-- было записано, а потом стёрто, и оба состояния выглядели бы одинаково.
	if type(data.Duration) == "number" then result.Duration = data.Duration end

	if type(data.AttackInfoDefaults) == "table" then
		local defaults: { [string]: any } = {}
		for key, value in data.AttackInfoDefaults do
			defaults[tostring(key)] = normalizeTagged(toTagged(value))
		end
		result.AttackInfoDefaults = defaults
	end

	return result
end

--- Печатает tagged-значение как исходный код Luau для эмиттера (§3, §8): модуль
--- сам Roblox-типов не создаёт, а пользователю нужен готовый вызов.
---
--- Форма `CFrame` в ТЗ (`CFrame.new(px, py, pz, rx, ry, rz)`) невалидна — такой
--- перегрузки конструктора нет, и сгенерированный скилл упал бы на загрузке.
--- Поэтому выводится умножение на `fromEulerAnglesYXZ`, парное к `ToOrientation`.
local function toLiteral(value: any): string
	if type(value) ~= "table" then return tostring(value) end

	local tag = value[TAG_KEY]
	if tag == "V3" then
		return string.format(
			"Vector3.new(%s, %s, %s)",
			tostring(value.x),
			tostring(value.y),
			tostring(value.z)
		)
	elseif tag == "CF" then
		return string.format(
			"CFrame.new(%s, %s, %s) * CFrame.fromEulerAnglesYXZ(%s, %s, %s)",
			tostring(value.px),
			tostring(value.py),
			tostring(value.pz),
			tostring(value.rx),
			tostring(value.ry),
			tostring(value.rz)
		)
	elseif tag == "C3" then
		return string.format(
			"Color3.fromRGB(%d, %d, %d)",
			math.round((value.r or 0) * 255),
			math.round((value.g or 0) * 255),
			math.round((value.b or 0) * 255)
		)
	end
	return tostring(value)
end
--- Пустой blueprint для нового скилла: ноль блоков, текущая версия, `{"Hit"}` в
--- `SkillCharacters`, потому что список должен быть непустым при наличии `Hitbox`
--- и UI всё равно предлагает это значение по умолчанию (§4).
local function newBlueprint(id: string, displayName: string?): { [string]: any }
	return {
		Id = id,
		DisplayName = displayName or id,
		Cooldown = 0,
		AssetSource = "Spec",
		SkillCharacters = { "Hit" },
		AnimationSlots = {},
		SoundSlots = {},
		Blocks = {},
		Metadata = { CreatedAt = 0, UpdatedAt = 0, Version = CURRENT_VERSION },
	}
end

return {
	CURRENT_VERSION = CURRENT_VERSION,
	encode = encode,
	decode = decode,
	newBlueprint = newBlueprint,
	toTagged = toTagged,
	fromTagged = fromTagged,
	toLiteral = toLiteral,
}
