--!strict
--- JSON без зависимости от версии рантайма.
---
--- Нужен `tools/generate-skill.luau` и приложению-конструктору скиллов, которое живёт
--- в отдельном репозитории и получает этот файл через `sync-core.ps1`.
---
--- Парсер написан здесь намеренно: `@lune/json` удалён из Lune начиная с 0.9,
--- а `@lune/serde` знает только свой формат, поэтому CLI не должен зависеть от
--- версии рантайма. Кодировщик дописан по той же причине — эмитится он там же,
--- где и разбирается, а не приходит извне.
---
--- `decode` разворачивает `null` в отсутствующий ключ объекта — ровно так же, как
--- `codec.encode` выбрасывает `nil`-поля, поэтому `{"FadeTime": null}` и
--- `{"FadeTime": <nil>}` дают одинаковый blueprint. В массивах `null` сохраняется
--- на своём месте, чтобы не сдвинуть индексы `Blocks`.
---
--- Ключи объектов на выходе `encode` сортируются: порядок вставки в Luau-таблице
--- не определён, а детерминированный вывод нужен и для сравнения снимков, и для
--- читаемого манифеста ассетов. Порядок массивов сохраняется — он значим.

local NULL = setmetatable({}, {
	__tostring = function()
		return "null"
	end,
})

type Parser = {
	text: string,
	pos: number,
}

local function fail(parser: Parser, reason: string): never
	error(`Invalid JSON at position {parser.pos}: {reason}`, 0)
end

local function skipSpace(parser: Parser)
	while parser.pos <= #parser.text do
		local char = string.sub(parser.text, parser.pos, parser.pos)
		if char == " " or char == "\t" or char == "\n" or char == "\r" then
			parser.pos += 1
		else
			break
		end
	end
end

local function expect(parser: Parser, char: string)
	if string.sub(parser.text, parser.pos, parser.pos) ~= char then
		fail(parser, `expected "{char}"`)
	end
	parser.pos += 1
end

local ESCAPES = {
	['"'] = '"',
	["\\"] = "\\",
	["/"] = "/",
	b = "\b",
	f = "\f",
	n = "\n",
	r = "\r",
	t = "\t",
}

--- `\uXXXX` → UTF-8. Суррогатные пары не склеиваются: в blueprint их нет, а молча
--- испорченный символ хуже явной ошибки.
local function utf8(code: number): string
	if code < 0x80 then return string.char(code) end
	if code < 0x800 then return string.char(0xC0 + math.floor(code / 64), 0x80 + code % 64) end
	return string.char(
		0xE0 + math.floor(code / 4096),
		0x80 + math.floor(code / 64) % 64,
		0x80 + code % 64
	)
end

local parseValue: (Parser) -> any

local function parseString(parser: Parser): string
	expect(parser, '"')
	local buffer = ""

	while true do
		local char = string.sub(parser.text, parser.pos, parser.pos)

		if char == "" then fail(parser, "unterminated string") end

		if char == '"' then
			parser.pos += 1
			return buffer
		end

		if char == "\\" then
			local escaped = string.sub(parser.text, parser.pos + 1, parser.pos + 1)
			local mapped = ESCAPES[escaped]

			if mapped ~= nil then
				buffer ..= mapped
				parser.pos += 2
			elseif escaped == "u" then
				local hex = string.sub(parser.text, parser.pos + 2, parser.pos + 5)
				local code = tonumber(hex, 16)

				if code == nil or #hex < 4 then fail(parser, "bad unicode escape") end

				buffer ..= utf8(code)
				parser.pos += 6
			else
				fail(parser, "unknown escape")
			end
		else
			buffer ..= char
			parser.pos += 1
		end
	end
end

local function parseNumber(parser: Parser): number
	local head = string.match(parser.text, "^%-?%d+", parser.pos)
	if head == nil then fail(parser, "expected a number") end

	local start = parser.pos
	parser.pos += #head

	local fraction = string.match(parser.text, "^%.%d+", parser.pos)
	if fraction ~= nil then
		parser.pos += #fraction
	end

	local exponent = string.match(parser.text, "^[eE][%+%-]?%d+", parser.pos)
	if exponent ~= nil then
		parser.pos += #exponent
	end

	local value = tonumber(string.sub(parser.text, start, parser.pos - 1))
	if value == nil then fail(parser, "malformed number") end
	return value
end

local function parseArray(parser: Parser): { any }
	expect(parser, "[")
	local result: { any } = {}

	skipSpace(parser)
	if string.sub(parser.text, parser.pos, parser.pos) == "]" then
		parser.pos += 1
		return result
	end

	while true do
		table.insert(result, parseValue(parser))

		skipSpace(parser)
		local char = string.sub(parser.text, parser.pos, parser.pos)

		if char == "," then
			parser.pos += 1
			skipSpace(parser)
		elseif char == "]" then
			parser.pos += 1
			return result
		else
			fail(parser, "expected , or ]")
		end
	end
end

local function parseObject(parser: Parser): { [string]: any }
	expect(parser, "{")
	local result: { [string]: any } = {}

	skipSpace(parser)
	if string.sub(parser.text, parser.pos, parser.pos) == "}" then
		parser.pos += 1
		return result
	end

	while true do
		skipSpace(parser)
		if string.sub(parser.text, parser.pos, parser.pos) ~= '"' then
			fail(parser, "expected a key")
		end

		local key = parseString(parser)
		skipSpace(parser)
		expect(parser, ":")
		skipSpace(parser)

		local value = parseValue(parser)
		if value ~= NULL then result[key] = value end

		skipSpace(parser)
		local char = string.sub(parser.text, parser.pos, parser.pos)

		if char == "," then
			parser.pos += 1
		elseif char == "}" then
			parser.pos += 1
			return result
		else
			fail(parser, "expected , or }")
		end
	end
end

parseValue = function(parser: Parser): any
	skipSpace(parser)
	local char = string.sub(parser.text, parser.pos, parser.pos)

	if char == "{" then return parseObject(parser) end
	if char == "[" then return parseArray(parser) end
	if char == '"' then return parseString(parser) end

	if string.match(parser.text, "^true", parser.pos) then
		parser.pos += 4
		return true
	end
	if string.match(parser.text, "^false", parser.pos) then
		parser.pos += 5
		return false
	end
	if string.match(parser.text, "^null", parser.pos) then
		parser.pos += 4
		return NULL
	end

	if char == "-" or string.match(parser.text, "^%d", parser.pos) ~= nil then
		return parseNumber(parser)
	end

	fail(parser, "unexpected character")
end

--- Разбирает JSON-текст в Luau-значение. Возвращает `NULL`-сентинел на месте
--- `null` внутри массива; в объекте `null` исчезает как отсутствующий ключ.
local function decode(text: string): any
	local parser: Parser = { text = text, pos = 1 }
	local value = parseValue(parser)

	skipSpace(parser)
	if parser.pos <= #parser.text then
		fail(parser, "trailing content after the top-level value")
	end

	return value
end

-- КОДИРОВАНИЕ ---------------------------------------------------------------

local CONTROL_ESCAPES = {
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
}

local function quote(value: string): string
	local buffer = '"'

	for index = 1, #value do
		local char = string.sub(value, index, index)
		local mapped = CONTROL_ESCAPES[char]

		if mapped ~= nil then
			buffer ..= mapped
		elseif char == '"' or char == "\\" then
			buffer ..= "\\" .. char
		elseif string.byte(char) < 32 then
			buffer ..= string.format("\\u%04x", string.byte(char))
		else
			buffer ..= char
		end
	end

	return buffer .. '"'
end

--- `%.15g` короче и читается лучше, но не для всех double'ов round-trip-ится в
--- те же биты, поэтому на несовпадении повторяем с `%.17g`. Целые печатаются
--- целыми, иначе кадры таймлайна выходили бы как `15.0`.
local function number(value: number): string
	if value ~= value or value == math.huge or value == -math.huge then return "null" end

	if value % 1 == 0 and math.abs(value) < 1e15 then return string.format("%d", value) end

	local short = string.format("%.15g", value)
	if tonumber(short) == value then return short end
	return string.format("%.17g", value)
end

--- Таблица считается массивом, только если её ключи — ровно `1..n`. Иначе в
--- JSON попадёт объект, а `ipairs`-семантика источника потеряется.
local function arrayLength(value: { [any]: any }): number?
	local count = 0

	for key in value do
		if type(key) ~= "number" then return nil end
		count += 1
	end

	for index = 1, count do
		if value[index] == nil then return nil end
	end

	return count
end

local encodeValue: (any, number, { [any]: true }, number?, number?) -> string

--- Цикл в данных blueprint невозможен, но обход без защиты на нём зависнет
--- молча — сентинел обрывает рекурсию явной ошибкой.
local function encodeTable(
	value: { [any]: any },
	depth: number,
	seen: { [any]: true },
	indent: number?,
	level: number?
): string
	if seen[value] then error("Cannot encode a table that contains itself", 0) end
	seen[value] = true

	local pretty = indent ~= nil
	local step: number = if pretty then indent else 0
	local current: number = level or 0

	local newline = if pretty then "\n" else ""
	local pad = if pretty then string.rep(" ", step * (current + 1)) else ""
	local closing = if pretty then string.rep(" ", step * current) else ""

	local count = arrayLength(value)
	local parts: { string } = {}

	if count ~= nil then
		for index = 1, count do
			table.insert(
				parts,
				pad
					.. encodeValue(
						value[index],
						depth + 1,
						seen,
						indent,
						if pretty then current + 1 else nil
					)
			)
		end
	else
		local keys: { any } = {}
		for key in value do
			if type(key) == "string" or type(key) == "number" then
				table.insert(keys, key)
			else
				error(`Cannot encode a table key of type {type(key)}`, 0)
			end
		end
		table.sort(keys, function(left: any, right: any): boolean
			return tostring(left) < tostring(right)
		end)

		for _, key in keys do
			local item = value[key] :: any
			if item ~= nil then
				table.insert(
					parts,
					pad
						.. quote(tostring(key))
						.. (if pretty then ": " else ":")
						.. encodeValue(
							item,
							depth + 1,
							seen,
							indent,
							if pretty then current + 1 else nil
						)
				)
			end
		end
	end

	seen[value] = nil

	if #parts == 0 then
		if count ~= nil then return "[]" end
		return "{}"
	end

	local separator = "," .. newline

	if count ~= nil then
		return "[" .. newline .. table.concat(parts, separator) .. newline .. closing .. "]"
	end

	return "{" .. newline .. table.concat(parts, separator) .. newline .. closing .. "}"
end

encodeValue = function(
	value: any,
	depth: number,
	seen: { [any]: true },
	indent: number?,
	level: number?
): string
	if depth > 256 then error("Value is nested too deeply to encode", 0) end

	local valueType = type(value)

	if value == nil or value == NULL then return "null" end
	if valueType == "boolean" then return if value then "true" else "false" end
	if valueType == "number" then return number(value) end
	if valueType == "string" then return quote(value) end
	if valueType == "table" then return encodeTable(value, depth, seen, indent, level) end

	error(`Cannot encode a value of type {valueType}`, 0)
end

--- Печатает Luau-значение как JSON. Опция `pretty` даёт отступ в `indent`
--- пробелов и переносы строк — для манифеста ассетов и файлов, которые читает
--- человек; без неё вывод однострочный и годится для транспорта.
local function encode(value: any, options: { pretty: boolean?, indent: number? }?): string
	return encodeValue(
		value,
		0,
		{},
		if options and options.pretty then (options.indent or 2) else nil
	)
end

return {
	decode = decode,
	encode = encode,
	NULL = NULL,
}
