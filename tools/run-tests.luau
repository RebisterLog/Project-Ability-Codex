--!strict
--- Runs every check of the project with one command.
---
---   lune run tools/run-tests.luau              the quality gates and all suites
---   lune run tools/run-tests.luau --json       same run, machine-readable report
---   lune run tools/run-tests.luau --gates      only the quality gates
---   lune run tools/run-tests.luau --only=syntax  only one quality gate
---   lune run tools/run-tests.luau --strict     treat a skipped gate as an error
---
--- Every suite is its own process: a failing suite does not stop the others from
--- being seen, and its exit code reaches the caller without wrappers.
---
--- The suites are found by themselves: `tests/` is walked recursively, while the
--- SkillConstructor suites are listed explicitly because they live in `src` next
--- to the package, and a general walk of `src` would drag in all the game code.
---
--- The exit code is non-zero if at least one check did not pass.

local Toolchain = require("./Toolchain")
local fs = require("@lune/fs")
local process = require("@lune/process")

--- Suites that do not live in `tests` and are therefore not found by the walk.
const EXTRA_SUITES = {
	{
		name = "SkillConstructor.structural",
		path = "src/shared/packages/SkillConstructor/tests/structural.luau",
	},
	{
		name = "SkillConstructor.codec",
		path = "src/shared/packages/SkillConstructor/tests/codec.luau",
	},
	{
		name = "SkillConstructor.emitter",
		path = "src/shared/packages/SkillConstructor/tests/emitter.luau",
	},
	{
		name = "SkillConstructor.against-spec",
		path = "src/shared/packages/SkillConstructor/tests/against-spec.luau",
	},
}

--- Directories the walk does not enter: `baseline` holds gate data, not checks.
--- Directories the walk does not enter: `baseline` holds gate data rather than
--- checks, and `support` holds modules shared between suites — running either
--- as a suite would report a meaningless pass.
const SKIP_DIRS = { "tests/baseline", "tests/support" }

--- Suite name from a path: `tests/skills/Punch.luau` → `skills.Punch`.
local function suiteName(root: string, path: string): string
	local relative = (Toolchain.relative(root, path):gsub("%.luau$", ""))
	local parts = Toolchain.split(relative)

	if #parts > 1 then table.remove(parts, 1) end

	return table.concat(parts, ".")
end

--- Recursive `.luau` collection over a directory, skipping unwanted subtrees.
local function collect(dir: string, skip: { [string]: boolean }?): { string }
	const found: { string } = {}

	local function walk(current: string)
		if skip and skip[current] then return end

		for _, entry in fs.readDir(current) do
			local path = `{current}/{entry}`

			if fs.isDir(path) then
				walk(path)
			elseif entry:sub(-5) == ".luau" then
				table.insert(found, path)
			end
		end
	end

	if fs.isDir(dir) then walk(dir) end

	return found
end

--- One `lune run`. The output is not inherited: `exec` intercepts the streams,
--- so it has to be printed here, otherwise the suite would stay silent.
local function runLune(
	root: string,
	path: string,
	extra: { string }?
): (boolean, string, string, number)
	const args: { string } = { "run", path }
	const values: { string } = extra or {}

	for _, value in values do
		table.insert(args, value)
	end

	local ok, result = pcall(process.exec, "lune", args, { cwd = root })

	if not ok then return false, "", tostring(result), 1 end

	return result.ok, result.stdout, result.stderr, result.code
end

local wantsJson = false
local strict = false
local gatesOnly = false
local gateFilter = ""

for _, arg in process.args do
	if arg == "--json" then
		wantsJson = true
	elseif arg == "--strict" then
		strict = true
	elseif arg == "--gates" then
		gatesOnly = true
	elseif arg:sub(1, 7) == "--only=" then
		gateFilter = arg:sub(8)
	end
end

const root = Toolchain.findRoot()
const started = os.clock()

--- The gates run first: if the code does not compile the suites will fail anyway,
--- but with a far more readable message.
const gateArgs: { string } = {}

if wantsJson then table.insert(gateArgs, "--json") end
if strict then table.insert(gateArgs, "--strict") end
if gateFilter ~= "" then table.insert(gateArgs, `--only={gateFilter}`) end

local gatesOk, gatesOut, gatesErr = runLune(root, "tools/check.luau", gateArgs)

--- The machine-mode gate report is parsed and embedded into the overall report:
--- two separate JSON documents in one output are awkward to read.
local gatesReport: any = nil

if wantsJson then
	local ok, json = pcall(require, "./json")
	local decoded = if ok then json.decode(gatesOut) else nil
	gatesReport = if type(decoded) == "table" then decoded else gatesOut
end

if not wantsJson then
	local text = (gatesOut:gsub("%s+$", ""))

	if text ~= "" then print(text) end
	if gatesErr ~= "" then print((gatesErr:gsub("%s+$", ""))) end
end

if not gatesOnly then
	const skip: { [string]: boolean } = {}

	for _, dir in SKIP_DIRS do
		skip[`{root}/{dir}`] = true
	end

	local suites: { { name: string, path: string } } = {}

	for _, path in collect(`{root}/tests`, skip) do
		table.insert(suites, { name = suiteName(root, path), path = path })
	end

	for _, extra in EXTRA_SUITES do
		if fs.isFile(`{root}/{extra.path}`) then table.insert(suites, extra) end
	end

	table.sort(suites, function(a, b)
		return a.name < b.name
	end)

	local results: { [string]: any } = {}
	local failed: { string } = {}

	for _, suite in suites do
		local suiteStarted = os.clock()
		local ok, out, err = runLune(root, suite.path)
		local duration = math.floor((os.clock() - suiteStarted) * 1000)

		if not ok then table.insert(failed, suite.name) end

		local tail = ""

		for _, line in Toolchain.lines(out) do
			tail = line
		end

		results[suite.name] = { ok = ok, durationMs = duration, summary = tail }

		if not wantsJson then
			print(`{ok and "ok  " or "FAIL"} {suite.name} ({duration} ms)`)

			if tail ~= "" then print(`     {tail}`) end
			if err ~= "" then print((err:gsub("%s+$", ""))) end
		end
	end

	if wantsJson then
		local json = require("./json")
		local report: { [string]: any } = {
			tool = "tests",
			ok = gatesOk and #failed == 0,
			gates = gatesReport,
		}

		for name, data in results do
			report[name] = data
		end

		print(json.encode(report, { pretty = true }))
	end

	print("")

	if #failed > 0 then
		print(`FAILED: {table.concat(failed, ", ")}`)
		process.exit(1)
	end
elseif wantsJson then
	-- `--gates` without suites: the report is still needed, otherwise the mode
	-- stays silent.
	local json = require("./json")
	print(json.encode({ tool = "tests", ok = gatesOk, gates = gatesReport }, { pretty = true }))
end

if not gatesOk then
	print("FAILED: quality gates")
	process.exit(1)
end

print(`OK ({math.floor((os.clock() - started) * 1000)} ms)`)
process.exit(0)
