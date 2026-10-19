--!strict
--- Text helpers for the static checks.
---
--- Three suites read skill source rather than run it: the effect-name check, the
--- field check and anything that needs the text of a call. They all need the same
--- two things, and both are easy to get subtly wrong:
---
--- - **comments must go.** A commented-out `VFXService:StartEffect(...)` is not a
---   call, and `-- self.ResetPunches = nil` is not a field. Reading the raw text
---   counts both, and the check then fails on code that does not exist.
--- - **an argument list is not split by commas.** `StartEffect(players, "Name",
---   instance, { Emit = ..., Speed = 1 })` has commas inside the third argument.
---
--- Everything here works on stripped text with string literals left intact, so
--- what the checks see is what the interpreter would see.

local Root = require("../../tools/SkillHarness/Root")
local fs = require("@lune/fs")

local Source = {}

local root = Root.find()

--- Removes comments, keeping strings and line structure intact.
---
--- Positions are preserved by replacing the comment with spaces rather than
--- deleting it: a check that reports line numbers has to point at the right one.
--- Long strings (`[[...]]`, `[==[...]==]`) are handled because the skill docblocks
--- are full of them, and a `--` inside a string must not start a comment.
function Source.strip(source: string): string
	local out = table.create(#source, " ")
	local index = 1
	local length = #source

	while index <= length do
		local pair = source:sub(index, index + 1)

		if pair == "--" then
			local longBrackets = source:match("^%-%-%[(=*)%[", index)

			if longBrackets then
				-- A block comment runs to the matching `]=]`, blanks included.
				local close = "]" .. longBrackets .. "]"
				local stop = source:find(close, index, true)
				local stopAt = if stop then (stop + #close - 1) else length

				for at = index, stopAt do
					out[at] = source:sub(at, at)

					-- Spelled out rather than as an if-expression: selene 0.32
					-- mis-parses a comparison condition in one and reports a
					-- phantom parse error that swallows the rest of the file.
					if out[at] ~= "\n" then out[at] = " " end
				end

				index = stopAt + 1
			else
				local stop = source:find("\n", index, true) or (length + 1)

				for at = index, stop - 1 do
					out[at] = " "
				end

				index = stop
			end
		elseif pair == "[[" or source:match("^%[(=*)%[", index) then
			local longBrackets = source:match("^%[(=*)%[", index) or ""
			local close = "]" .. longBrackets .. "]"
			local stop = source:find(close, index + #longBrackets + 1, true)
			local stopAt = if stop then (stop + #close - 1) else length

			for at = index, stopAt do
				out[at] = source:sub(at, at)
			end

			index = stopAt + 1
		elseif pair == '"' or pair == "'" then
			local quote = pair
			local stop = index

			repeat
				out[stop] = source:sub(stop, stop)
				stop += 1
			until stop > length
				or source:sub(stop, stop) == quote
				or source:sub(stop - 1, stop - 1) == "\\"

			index = stop
		else
			out[index] = source:sub(index, index)
			index += 1
		end
	end

	return table.concat(out)
end

--- Splits an argument list into its top-level arguments, given the text *between*
--- the parentheses. Brackets and strings are skipped, so a table or a nested call
--- does not cut the list in half; nesting starts at depth zero here, because the
--- outermost brackets have already been taken off by the caller.
function Source.arguments(source: string): { string }
	local args: { string } = {}
	local depth = 0
	local start = 1
	local index = 1
	local length = #source

	while index <= length do
		local char = source:sub(index, index)
		local pair = source:sub(index, index + 1)

		if pair == '"' or pair == "'" then
			index += 1

			while index <= length do
				if source:sub(index, index) == "\\" then
					index += 2
				elseif source:sub(index, index) == pair then
					break
				else
					index += 1
				end
			end
		elseif char == "(" or char == "{" or char == "[" then
			depth += 1
		elseif char == ")" or char == "}" or char == "]" then
			depth -= 1
		elseif char == "," and depth == 0 then
			table.insert(args, source:sub(start, index - 1))
			start = index + 1
		end

		index += 1
	end

	table.insert(args, source:sub(start))

	return args
end

--- Every `:method(` call site in the source, with the arguments after the
--- opening parenthesis.
---
--- Only method calls are matched: `VFXService:StartEffect(...)` is a call,
--- `function VFXService:StartEffect(...)` is a declaration, and only the first can
--- send a name that has to exist.
function Source.calls(
	source: string,
	methods: { string }
): { { arguments: { string }, index: number } }
	const stripped = Source.strip(source)
	const found: { { arguments: { string }, index: number } } = {}

	for _, method in methods do
		local from = 1

		while true do
			local at = stripped:find(`:%s*%s*%s`, from, true)

			if at == nil then break end

			local after = stripped:sub(at + 1)
			local name, rest = after:match("^(%a[%w_]*)%s*%(")

			if name == method then
				-- Walk to the parenthesis that closes the call, then split.
				local open = at + 1 + #after - #rest
				local close = Source.matching(stripped, open)

				if close then
					table.insert(found, {
						arguments = Source.arguments(stripped:sub(open + 1, close - 1)),
						index = at,
					})
				end

				from = close or (open + 1)
			else
				from = at + 1
			end
		end
	end

	table.sort(found, function(a, b)
		return a.index < b.index
	end)

	return found
end

--- Index of the bracket closing the one at `open`, or nil if the source ends
--- first. Written as its own pass because both the argument splitter and the call
--- finder need it and neither can see the other's bracket handling.
function Source.matching(source: string, open: number): number?
	local closing = { ["("] = ")", ["{"] = "}", ["["] = "]" }
	local stack: { string } = {}
	local index = open

	while index <= #source do
		local char = source:sub(index, index)
		local pair = source:sub(index, index + 1)

		if pair == '"' or pair == "'" then
			index += 1

			while index <= #source do
				if source:sub(index, index) == "\\" then
					index += 2
				elseif source:sub(index, index) == pair then
					break
				else
					index += 1
				end
			end
		elseif closing[char] then
			table.insert(stack, closing[char])
		elseif char == ")" or char == "}" or char == "]" then
			if stack[#stack] ~= char then return nil end

			table.remove(stack)

			if #stack == 0 then return index end
		end

		index += 1
	end

	return nil
end

--- Reads `self.<field>` from a source file: what is read, and what is assigned.
---
--- `self[` is reported separately: a computed field cannot be resolved by reading
--- the text, and pretending otherwise would make the check wrong rather than
--- merely quiet.
function Source.selfFields(source: string): {
	read: { [string]: boolean },
	written: { [string]: boolean },
	computed: boolean,
}
	const stripped = Source.strip(source)
	const read: { [string]: boolean } = {}
	const written: { [string]: boolean } = {}
	local computed = false

	for name in stripped:gmatch("self%s*%.%s*([%a_][%w_]*)") do
		read[name] = true
	end

	-- An assignment is `self.X =` and nothing else; `==`, `<=`, `>=` and `<` are
	-- comparisons, and a single `=` on its own line is a block keyword.
	for name in stripped:gmatch("self%s*%.%s*([%a_][%w_]*)%s*=[^=]") do
		written[name] = true
	end

	if stripped:match("self%s*%[") then computed = true end

	return { read = read, written = written, computed = computed }
end

--- Reads the fields declared for a type in `src/server/types.luau`.
---
--- The class shape is taken from the type rather than from a list in the test, so
--- that adding a field to `Skill` makes this accept it with no edit here.
function Source.typeFields(typeName: string): { [string]: boolean }
	const path = `{root}/src/server/types.luau`
	local fields: { [string]: boolean } = {}

	if not fs.isFile(path) then return fields end

	const source = Source.strip(fs.readFile(path))

	for block in source:gmatch("type%s+" .. typeName .. "%s*=%s*{(.-)\n}") do
		for name in block:gmatch("([%a_][%w_]*)%s*:") do
			fields[name] = true
		end
	end

	return fields
end

--- Files under a directory, recursively, as paths relative to the repository.
function Source.files(dir: string): { string }
	const found: { string } = {}

	local function walk(current: string)
		if not fs.isDir(current) then return end

		for _, entry in fs.readDir(current) do
			local path = `{current}/{entry}`

			if fs.isDir(path) then
				walk(path)
			elseif entry:sub(-5) == ".luau" then
				table.insert(found, (path:gsub("^" .. root:gsub("%p", "%%%0") .. "/", "")))
			end
		end
	end

	walk(`{root}/{dir}`)

	table.sort(found)

	return found
end

--- Reads a repository file as stripped text.
function Source.read(path: string): string
	return Source.strip(fs.readFile(`{root}/{path}`))
end

--- Line number of a character position in the stripped text.
function Source.lineAt(source: string, index: number): number
	local line = 1

	for at = 1, math.min(index, #source) do
		if source:sub(at, at) == "\n" then
			line += 1
		end
	end

	return line
end

return Source
