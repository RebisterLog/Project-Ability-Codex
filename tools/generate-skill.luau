--!strict
--- CLI: blueprint в JSON-форме → модуль скилла `src/server/skills/<Id>.luau` (§11).
---
--- Запуск из любого каталога:
---   lune run tools/generate-skill.luau <input.json> [--force] [--stdout] [--no-stylua]
---
--- Инструмент не требует Roblox API: генерация идёт поверх JSON-формы (§8), поэтому
--- тот же файл можно положить в репозиторий и запустить в CI без Roblox. Проверки,
--- требующие `Spec` (21–23, 25–27 и W7), здесь не выполняются — они живут в игре,
--- в `PreviewTab`.
---
--- Правила игры:
---   - предупреждения `validateStructural` печатаются, но не мешают генерации;
---   - структурные ошибки и `Errors` эмиттера останавливают работу с кодом `1`, и
---     целевой файл не трогается — битый модуль в `skills` хуже, чем его отсутствие;
---   - существующий файл перезаписывается только с `--force`;
---   - `stylua` запускается, если он доступен, и его ошибка не блокирует генерацию
---     (§11: форматирование — отдельный ручной шаг).
---
--- Сырой вывод эмиттера не отформатирован: отступы вложенных секций `Stun` / `Block`
--- и разбиение длинных вызовов держит `stylua`. Поэтому `--stdout` печатает ровно то,
--- что попадёт в файл после `--no-stylua`, а рабочий файл всегда форматируется.
---
--- Парсер JSON написан здесь намеренно: `@lune/json` удалён из Lune начиная с 0.9,
--- а `@lune/serde` умеет только `encode`/`decode` своего собственного формата. Ручной
--- парсер нужен для того, чтобы CLI не зависел от версии рантайма.
---
--- `null` разворачивается в отсутствующий ключ — ровно так же, как `codec.encode`
--- выбрасывает `nil`-поля, поэтому `{"FadeTime": null}` и `{"FadeTime": <nil>}` дают
--- одинаковый blueprint. В массивах `null` сохраняется на своём месте, чтобы не
--- сдвинуть индексы `Blocks`.

local fs = require("@lune/fs")
local process = require("@lune/process")

-- ПАРСЕР JSON ---------------------------------------------------------------

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

local function decodeJson(text: string): any
	local parser: Parser = { text = text, pos = 1 }
	local value = parseValue(parser)

	skipSpace(parser)
	if parser.pos <= #parser.text then
		fail(parser, "trailing content after the top-level value")
	end

	return value
end

-- ПУТИ И ВЫВОД --------------------------------------------------------------

--- Склейка путей своя: `fs.join` в этой версии Lune нет, а `fs.absolute` нет тоже.
--- Разделитель `/` понимается и на Windows.
local function isSeparator(char: string): boolean
	return char == "/" or char == "\\"
end

--- Символы сравниваются напрямую: в этом билде Luau класс `[/\\]` не ловит
--- обратный слэш, а `string.gsub` на путях — отличный способ построить неверный путь.
local function trimTrailing(path: string): string
	local last = #path

	while last > 0 and isSeparator(string.sub(path, last, last)) do
		last -= 1
	end

	return string.sub(path, 1, last)
end

local function trimLeading(path: string): string
	local first = 1
	while first <= #path and isSeparator(string.sub(path, first, first)) do
		first += 1
	end

	return string.sub(path, first)
end

local function joinPath(...: string): string
	local arguments = table.pack(...)
	local pieces: { string } = {}

	for index = 1, arguments.n do
		local piece = trimTrailing(arguments[index])
		if piece ~= "" then table.insert(pieces, piece) end
	end

	local result = pieces[1] or ""

	for index = 2, #pieces do
		result ..= "/" .. trimLeading(pieces[index])
	end

	return result
end

local function isAbsolute(path: string): boolean
	if isSeparator(string.sub(path, 1, 1)) then return true end
	return string.sub(path, 2, 2) == ":" and isSeparator(string.sub(path, 3, 3))
end

--- Скрипт лежит в `tools/`, значит корень репозитория — на уровень выше. `process.cwd`
--- не годится: CLI можно запустить из любого каталога.
local function repoRoot(): string
	local scriptPath = debug.info(1, "s")
	local directory = string.match(scriptPath, "^(.*)[/\\][^/\\]*$") or "."
	return (string.gsub(directory, "[/\\]tools$", ""))
end

local function toRelative(path: string, root: string): string
	local prefix = root .. "/"
	if string.sub(path, 1, #prefix) == prefix then return string.sub(path, #prefix + 1) end
	return path
end

local function formatPath(path: { string | number }?): string?
	if type(path) ~= "table" then return nil end

	local parts: { string } = {}
	for _, value in path do
		table.insert(parts, tostring(value))
	end

	return table.concat(parts, ".")
end

--- Диагностика валидатора и эмиттера приходит одним списком — печатается одним стилем.
local function report(label: string, issues: { any }, fallbackCode: string)
	for _, issue in issues do
		local code = if type(issue) == "table" and type(issue.Code) == "string"
			then issue.Code
			else fallbackCode
		local message = if type(issue) == "table" and type(issue.Message) == "string"
			then issue.Message
			else tostring(issue)
		local at = formatPath(if type(issue) == "table" then issue.Path else nil)

		if at == nil then
			print(`{label}: [{code}] {message}`)
		else
			print(`{label}: [{code}] {message} at {at}`)
		end
	end
end

-- АРГУМЕНТЫ -----------------------------------------------------------------

type Args = {
	input: string?,
	force: boolean,
	stdout: boolean,
	noStylua: boolean,
	help: boolean,
	unknown: { string },
}

local function parseArgs(argv: { string }): Args
	local args: Args = {
		input = nil,
		force = false,
		stdout = false,
		noStylua = false,
		help = false,
		unknown = {},
	}

	for _, arg in argv do
		if arg == "--force" or arg == "-f" then
			args.force = true
		elseif arg == "--stdout" then
			args.stdout = true
		elseif arg == "--no-stylua" then
			args.noStylua = true
		elseif arg == "--help" or arg == "-h" then
			args.help = true
		elseif string.sub(arg, 1, 1) == "-" then
			table.insert(args.unknown, arg)
		elseif args.input == nil then
			args.input = arg
		else
			table.insert(args.unknown, arg)
		end
	end

	return args
end

local function usage(): { string }
	return {
		"Usage: lune run tools/generate-skill.luau <input.json> [options]",
		"",
		"Options:",
		"  -f, --force      перезаписать существующий src/server/skills/<Id>.luau",
		"      --stdout     напечатать исходник модуля, не записывая файл и не форматируя",
		"      --no-stylua  не запускать stylua после записи",
		"  -h, --help       эта справка",
		"",
		"Коды возврата: 0 — модуль сгенерирован, 1 — ошибка ввода или валидации.",
		"",
		"Примеры:",
		"  lune run tools/generate-skill.luau blueprints/fire-punch.json",
		"  lune run tools/generate-skill.luau blueprints/fire-punch.json --force",
		"  lune run tools/generate-skill.luau blueprints/fire-punch.json --stdout",
	}
end

-- ГЕНЕРАЦИЯ -----------------------------------------------------------------

type Prepared = {
	source: string,
	target: string,
	relative: string,
}

--- Имя файла не должно содержать ничего, что ломает путь в Windows.
--- Символы, которые нельзя положить в имя файла на Windows, плюс управляющие.
local FORBIDDEN_ID_CHARS = {
	["/"] = true,
	["\\"] = true,
	[":"] = true,
	["*"] = true,
	["?"] = true,
	['"'] = true,
	["<"] = true,
	[">"] = true,
	["|"] = true,
}

local function idProblem(id: string): string?
	for index = 1, #id do
		local char = string.sub(id, index, index)
		local code = string.byte(char)

		if code ~= nil and (code < 32 or code == 127) then return "control characters" end
		if FORBIDDEN_ID_CHARS[char] ~= nil then return `"\{char}"` end
	end

	return nil
end

local function prepare(root: string, blueprint: any): (Prepared?, string?)
	local validator = require("../src/shared/packages/SkillConstructor/validator")
	local emitter = require("../src/shared/packages/SkillConstructor/emitter")

	local structural = validator.validateStructural(blueprint)
	if type(structural) ~= "table" then
		return nil, "validateStructural returned an unexpected value"
	end

	for _, warning in structural.warnings or {} do
		report("WARN", { warning }, "W")
	end

	if #(structural.errors or {}) > 0 then
		report("ERROR", structural.errors, "E")
		return nil, "structural validation failed"
	end

	local result = emitter.emit(blueprint)
	if type(result) ~= "table" then return nil, "emitter returned an unexpected value" end

	if #(result.Errors or {}) > 0 then
		report("ERROR", result.Errors, "EMIT")
		return nil, "emitter reported errors"
	end

	if type(result.Source) ~= "string" or result.Source == "" then
		return nil, "emitter produced no source"
	end

	local id = blueprint.Id
	if type(id) ~= "string" or id == "" then
		return nil, "Blueprint.Id is missing or not a string"
	end

	local forbidden = idProblem(id)
	if forbidden ~= nil then return nil, `"{id}" cannot be a file name: contains {forbidden}` end

	local target = joinPath(root, "src", "server", "skills", `{id}.luau`)

	return { source = result.Source, target = target, relative = toRelative(target, root) }, nil
end

--- `stylua` — необязательный шаг: отсутствие бинарника или его ненулевой код не делают
--- сгенерированный файл неправильным.
local function formatFile(path: string)
	local ok, result = pcall(process.exec, "stylua", { path }, { stdio = "inherit" })
	if not ok then return end

	if type(result) == "table" and result.code ~= 0 then
		print(`WARN: stylua exited with code {tostring(result.code)}; run it manually`)
	end
end

local function main(): number
	local args = parseArgs(process.args)

	if args.help then
		for _, line in usage() do
			print(line)
		end
		return 0
	end

	if #args.unknown > 0 then
		print(`ERROR: unknown argument "{args.unknown[1]}"`)
		return 1
	end

	if args.input == nil then
		print("ERROR: <input.json> is required")
		for _, line in usage() do
			print(line)
		end
		return 1
	end

	local root = repoRoot()
	local inputPath = if isAbsolute(args.input) then args.input else joinPath(root, args.input)

	if not fs.isFile(inputPath) then
		print(`ERROR: input file not found: {toRelative(inputPath, root)}`)
		return 1
	end

	local readOk, text = pcall(fs.readFile, inputPath)
	if not readOk or type(text) ~= "string" then
		print(`ERROR: cannot read {toRelative(inputPath, root)}`)
		return 1
	end

	local parseOk, blueprint = pcall(decodeJson, text)
	if not parseOk then
		print(`ERROR: {blueprint}`)
		return 1
	end

	if type(blueprint) ~= "table" then
		print("ERROR: blueprint JSON must be an object")
		return 1
	end

	local prepared, failure = prepare(root, blueprint)
	if prepared == nil then
		print(`ERROR: {failure or "generation failed"}`)
		return 1
	end

	-- `--stdout` — это пайп: наружу уходит ровно модуль, диагностика уже напечатана.
	if args.stdout then
		print(prepared.source)
		return 0
	end

	local exists = fs.isFile(prepared.target)
	if exists and not args.force then
		print(`ERROR: {prepared.relative} already exists, pass --force to overwrite`)
		return 1
	end
	if exists then print(`WARN: overwriting {prepared.relative}`) end

	local directory = joinPath(root, "src", "server", "skills")
	if not fs.isDir(directory) then
		local made, makeError = pcall(fs.writeDir, directory)
		if not made then
			print(`ERROR: cannot create {toRelative(directory, root)}: {makeError}`)
			return 1
		end
	end

	local written, writeError = pcall(fs.writeFile, prepared.target, prepared.source)
	if not written then
		print(`ERROR: cannot write {prepared.relative}: {writeError}`)
		return 1
	end

	if not args.noStylua then formatFile(prepared.target) end

	print(`OK: generated {prepared.relative}`)
	return 0
end

process.exit(main())
