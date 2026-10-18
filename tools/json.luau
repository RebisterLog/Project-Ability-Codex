--!strict
--- JSON without a dependency on the runtime version.
---
--- Needed by `tools/generate-skill.luau` and by the skill constructor app, which
--- lives in a separate repository and receives this file through `sync-core.ps1`.
---
--- The parser is written here on purpose: `@lune/json` was removed from Lune in
--- 0.9, and `@lune/serde` only knows its own format, so the CLI must not depend
--- on the runtime version. The encoder is hand-written for the same reason — it is
--- emitted wherever it is also parsed, not brought in from outside.
---
--- `decode` folds `null` into an absent object key — exactly like `codec.encode`
--- drops `nil` fields, so `{"FadeTime": null}` and `{"FadeTime": <nil>}` yield the
--- same blueprint. Inside arrays `null` is kept in place, so that `Blocks` indices
--- never shift.
---
--- Object keys are sorted on the way out of `encode`: insertion order in a Luau
--- table is undefined, and deterministic output is needed both for snapshot
--- comparison and for a readable asset manifest. Array order is preserved — it
--- carries meaning.

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

--- `\uXXXX` → UTF-8. Surrogate pairs are not joined: blueprints never contain
--- them, and a silently mangled character is worse than an explicit error.
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

				-- The Luau analyzer does not narrow `number?` after a call to a
				-- function declared as never returning, so here and for the rest
				-- of the code the check is duplicated as a type assertion:
				-- `fail` really does throw.
				buffer ..= utf8(code :: number)
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
	parser.pos += #(head :: string)

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
	return value :: number
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

	-- Returning `fail`'s value instead of a bare call: the path is unreachable,
	-- but this way the function looks complete to the analyzer.
	return fail(parser, "unexpected character")
end

--- Parses JSON text into a Luau value. Returns the `NULL` sentinel where `null`
--- stood inside an array; inside an object `null` disappears as an absent key.
local function decode(text: string): any
	local parser: Parser = { text = text, pos = 1 }
	local value = parseValue(parser)

	skipSpace(parser)
	if parser.pos <= #parser.text then
		fail(parser, "trailing content after the top-level value")
	end

	return value
end

-- ENCODING ------------------------------------------------------------------

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

--- `%.15g` is shorter and reads better, but does not round-trip to the same bits
--- for every double, so on a mismatch we retry with `%.17g`. Integers print as
--- integers, otherwise timeline frames would come out as `15.0`.
local function number(value: number): string
	if value ~= value or value == math.huge or value == -math.huge then return "null" end

	if value % 1 == 0 and math.abs(value) < 1e15 then return string.format("%d", value) end

	local short = string.format("%.15g", value)
	if tonumber(short) == value then return short end
	return string.format("%.17g", value)
end

--- A table counts as an array only when its keys are exactly `1..n`. Otherwise
--- an object would land in the JSON and the `ipairs` semantics of the source
--- would be lost.
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

--- A cycle in blueprint data is impossible, but walking without a guard would
--- hang on it silently — the sentinel ends the recursion with an explicit error.
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
	local step: number = indent or 0
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

--- Prints a Luau value as JSON. The `pretty` option gives `indent` spaces of
--- indentation and real line breaks — for the asset manifest and for files a
--- human reads; without it the output is one line and good for transport.
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
