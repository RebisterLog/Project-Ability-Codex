--!strict
--- CLI for the quality gates.
---
---   lune run tools/check.luau                  all gates, human-readable output
---   lune run tools/check.luau --json           same report, machine-readable, for agents and CI
---   lune run tools/check.luau --only=analyze   a single gate (comma-separate for several)
---   lune run tools/check.luau --strict         treat a skipped gate as an error
---   lune run tools/check.luau --update-baseline overwrite the baselines with the current findings
---
--- The exit code is non-zero if at least one gate failed: both
--- `tools/run-tests.luau` and any CI check are built on that.

local Quality = require("./Quality")
local Toolchain = require("./Toolchain")
local json = require("./json")
local process = require("@lune/process")

--- Returns the parsed options and the `--json` flag: there are two of them, so the
--- return type is spelled out, otherwise the second result is lost at the call
--- site.
local function parseOptions(args: { string }): (Quality.Options, boolean)
	const options: Quality.Options = {
		strict = false,
		update = false,
		only = {},
		refreshSourcemap = false,
	}

	local wantsJson = false

	for _, arg in args do
		if arg == "--json" then
			wantsJson = true
		elseif arg == "--strict" then
			options.strict = true
		elseif arg == "--update-baseline" then
			options.update = true
		elseif arg == "--refresh-sourcemap" then
			options.refreshSourcemap = true
		elseif arg:sub(1, 7) == "--only=" then
			-- One capture gives one variable: the second value from `gmatch` is the position
			-- in the string, not a value, and `table.insert(list, nil)` silently
			-- does nothing.
			for name in arg:sub(8):gmatch("[^,]+") do
				table.insert(options.only, name)
			end
		elseif arg == "--help" or arg == "-h" then
			print("usage: lune run tools/check.luau [--json] [--strict] [--only=gate,...]")
			print("       [--update-baseline] [--refresh-sourcemap]")
			process.exit(0)
		end
	end

	return options, wantsJson
end

--- Report for machines: the keys are fixed so CI checks can be built on top of it
--- without parsing human output.
local function toJson(results: { Quality.GateResult }, duration: number): string
	const gates: { any } = {}
	local ok = true
	local durationMs = 0

	for _, result in results do
		durationMs += result.durationMs

		if result.status ~= "pass" then ok = false end

		local gate: { [string]: any } = {
			name = result.name,
			status = result.status,
			checked = result.checked,
			known = result.known,
			added = result.added,
			removed = result.removed,
			durationMs = result.durationMs,
			failures = result.failures,
		}

		if result.skipped then gate.skipped = result.skipped end

		table.insert(gates, gate)
	end

	return json.encode(
		{ tool = "quality", ok = ok, durationMs = durationMs, gates = gates },
		{ pretty = true }
	)
end

local options, wantsJson = parseOptions(process.args)

local root = Toolchain.findRoot()
local started = os.clock()
local results = Quality.run(root, options)

if wantsJson then
	print(toJson(results, math.floor((os.clock() - started) * 1000)))
else
	print(Quality.report(results))

	if options.update then print("baselines updated in tests/baseline") end
end

for _, result in results do
	if result.status == "fail" then process.exit(1) end
end

process.exit(0)
