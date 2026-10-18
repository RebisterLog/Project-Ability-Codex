--!strict
--- Autoformatting of the codebase.
---
---   lune run tools/format.luau             check our own code: tools and tests
---   lune run tools/format.luau --fix       format our own code
---   lune run tools/format.luau --fix --src format src as well
---
--- The key detail is line endings. `stylua.toml` sets `line_endings = "Unix"`,
--- while a Windows working copy arrives with CRLF, because `core.autocrlf` is on.
--- A naive `stylua` run would rewrite the line endings of all 700 files and
--- produce a diff that says nothing at all. So the files are split into groups by
--- their current line endings, and each group is formatted with its own
--- `--line-endings`.
---
--- Vendored packages are never touched: they arrived from outside.

local Toolchain = require("./Toolchain")
local fs = require("@lune/fs")
local process = require("@lune/process")

--- Our own code: what the format gate checks strictly.
const OWN_DIRS = { "tools", "tests" }

--- Line endings in a file: `\r\n` means the file came from Windows.
local function hasCrlf(path: string): boolean
	return fs.readFile(path):find("\r\n", 1, true) ~= nil
end

--- Sorts files into line-ending groups and calls stylua once per group.
local function runStylua(root: string, binary: string, files: { string }, mode: string): number
	local groups: { [string]: { string } } = { Unix = {}, Windows = {} }

	for _, file in files do
		table.insert(groups[if hasCrlf(file) then "Windows" else "Unix"], file)
	end

	local changed = 0

	for endings, group in groups do
		if #group > 0 then
			-- In fix mode stylua is silent and always exits with 0, so "did anything
			-- change?" is decided by comparing the contents before and after:
			-- otherwise the command would report "nothing to format" on dirty
			-- files.
			local before: { [string]: string } = {}

			if mode == "fix" then
				for _, file in group do
					before[file] = fs.readFile(file)
				end
			end

			local args: { string } = { `--line-endings={endings}` }

			if mode == "check" then table.insert(args, "--check") end

			for _, file in group do
				table.insert(args, file)
			end

			local ok, result = pcall(process.exec, binary, args, { cwd = root })

			if not ok then
				print(`stylua failed: {result}`)
				process.exit(1)
			end

			if mode == "check" then
				for path in result.stdout:gmatch("Diff in ([^\r\n]+):") do
					print(Toolchain.relative(root, Toolchain.toUnix(path)))
					changed += 1
				end
			else
				for _, file in group do
					if fs.readFile(file) ~= before[file] then
						print(Toolchain.relative(root, file))
						changed += 1
					end
				end
			end
		end
	end

	return changed
end

local wantsFix = false
local wantsSrc = false

for _, arg in process.args do
	if arg == "--fix" then
		wantsFix = true
	elseif arg == "--src" then
		wantsSrc = true
	end
end

local root = Toolchain.findRoot()
const binary = Toolchain.find(root, "stylua")

-- `return`, not `process.exit`: the analyzer does not narrow `string?` after a
-- call declared as never returning, and `binary` would stay `string?` for the
-- rest of the file.
if binary == nil then
	print("stylua not found: set PAC_TOOLS_DIR or put stylua next to lune")
	return
end

const vendored = Toolchain.vendoredSet(root)
local files: { string } = {}

for _, dir in OWN_DIRS do
	for _, file in Toolchain.scripts(`{root}/{dir}`) do
		table.insert(files, file)
	end
end

if wantsSrc then
	for _, file in Toolchain.scripts(`{root}/src`, vendored) do
		table.insert(files, file)
	end
end

table.sort(files)
print(
	`{wantsFix and "formatting" or "checking"} {#files} files ({if wantsSrc
		then "tools, tests, src"
		else "tools, tests"})`
)

-- The parentheses are mandatory: an `if ... then ... else ...` without them in an
-- argument list expands into two values and adds a stray argument.
const changed = runStylua(root, binary, files, (if wantsFix then "fix" else "check"))

if wantsFix then
	print(changed > 0 and `{changed} files reformatted` or "nothing to reformat")
	process.exit(0)
end

if changed > 0 then
	print("")
	print("run: lune run tools/format.luau --fix")
	process.exit(1)
end

print("all formatted")
process.exit(0)
