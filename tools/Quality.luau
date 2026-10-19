--!strict
--- Quality gates: syntax, formatting, lint and types.
---
--- The gates run in increasing cost order, and each next one is only worth
--- running if the previous one is clean:
---
---   syntax   — `luau-compile --only-parse`, ~10 ms for the whole repository. It
---               knows nothing about Roblox, but it catches a syntax error before
---               `loadstring` in the harness or Studio ever sees it.
---   format   — `stylua --check`. Checked in two passes, one per line-ending
---               style: a Windows working copy arrives with CRLF while `stylua.toml`
---               asks for Unix, and a file that differs only in line endings must
---               not count as unformatted.
---   lint     — `selene`, configured by `selene.toml` with the Roblox standard
---               library. It answers what the type checker does not: unused
---               variables, shadowing, `global_usage`. Style stays in stylua's
---               hands, so `multiple_statements` is turned off over there.
---   analyze  — `luau-lsp analyze` with the Roblox global definitions and a
---               sourcemap: without them the analyzer treats `game`, `Vector3` and
---               `CFrame` as unknown and floods every line of game code with false
---               errors.
---
--- Known findings live in `tests/baseline` and do not fail the gate: only new
--- ones do. Vendored packages are excluded outright — they arrived from outside
--- and not a single finding in them is actionable.
---
--- A missing binary is a skipped gate with a warning, not a failure: a machine
--- without `stylua` must still be able to run the tests. `--strict` turns a skip
--- into an error — that is how CI tells "nothing to check with" apart from
--- "checked, clean".

local Baseline = require("./Baseline")
local Toolchain = require("./Toolchain")
local fs = require("@lune/fs")
local process = require("@lune/process")

export type Options = {
	strict: boolean,
	update: boolean,
	only: { string },
	refreshSourcemap: boolean,
}

export type GateResult = {
	name: string,
	status: string,
	checked: number,
	known: number,
	added: number,
	removed: number,
	durationMs: number,
	failures: { string },
	skipped: string?,
}

local Quality = {}

--- Files per single run. The Windows command line is limited to ~32 KB, and paths
--- with quotes take ~80 bytes each, so the list has to be cut.
const BATCH = 40

--- Our own code, unconditionally: the baseline for `tools` and `tests` is a
--- deviation from zero, not a list of bad spots.
const OWN_PREFIXES = { "tools/", "tests/" }

--- The key a finding is stored under in the baseline. Line and column numbers are
--- deliberately left out: they shift on any edit to a neighbouring line, and the
--- baseline would be rewritten wholesale instead of updated in place.
local function findingKey(root: string, path: string, code: string, message: string): string
	return `{Toolchain.relative(root, path)} {code}: {message}`
end

local function ownFile(path: string): boolean
	for _, prefix in OWN_PREFIXES do
		if path:sub(1, #prefix) == prefix then return true end
	end

	return false
end

--- The findings that fail the gate: new ones plus any in our own code. The
--- baseline for `tools` and `tests` is a deviation from zero, so nothing ever
--- lands there, but the check stays: hand-editing the baseline must not silently
--- disable the gate.
---
--- The list of vanished findings is returned too: it breaks nothing, but it says
--- the baseline is due for a cleanup via `--update-baseline`.
local function gateFailures(
	current: { [string]: string },
	known: { [string]: true }
): ({ string }, { string })
	local delta = Baseline.diff(current, known)
	local failures: { string } = {}

	for _, finding in delta.added do
		local path = current[finding] :: string

		if ownFile(path) or not known[finding] then table.insert(failures, finding) end
	end

	table.sort(failures)

	return failures, delta.removed
end

--- Splits a list into batches: `exec` takes an argument list, not a file holding a
--- list, so a long list has to be cut here.
local function batches(files: { string }, size: number): { { string } }
	const chunks: { { string } } = {}
	local index = 1

	while index <= #files do
		local chunk: { string } = {}

		for offset = 0, size - 1 do
			local file = files[index + offset]

			if not file then break end

			table.insert(chunk, file)
		end

		table.insert(chunks, chunk)
		index += #chunk
	end

	return chunks
end

--- A skipped gate: the reason goes into the report so that a "green" run does not
--- look like "everything was checked".
local function skipped(name: string, reason: string, checked: number, started: number): GateResult
	return {
		name = name,
		status = "skip",
		checked = checked,
		known = 0,
		added = 0,
		removed = 0,
		durationMs = math.floor((os.clock() - started) * 1000),
		failures = {},
		skipped = reason,
	}
end

--- The syntax gate. A parse error is always a regression, with no baseline: code
--- that does not compile cannot work in the game either. That also leaves nothing
--- for `options` to decide here, but the gate keeps the shared signature so that
--- `Quality.run` can hold all four in one table.
function Quality.syntax(root: string, files: { string }, _options: Options): GateResult
	const started = os.clock()
	const binary = Toolchain.find(root, "luau-compile")

	if not binary then return skipped("syntax", "luau-compile not found", #files, started) end

	const failures: { string } = {}
	local seen: { [string]: boolean } = {}

	for _, chunk in batches(files, BATCH) do
		local args: { string } = { "--only-parse" }

		for _, file in chunk do
			table.insert(args, file)
		end

		local ok, result = pcall(process.exec, binary, args, { cwd = root })

		if ok then
			for _, line in Toolchain.lines(result.stdout .. "\n" .. result.stderr) do
				const path, message = line:match("^(.-)%(%d+,%d+%)%s*:%s*([^\r\n]+)")

				if path and message then
					const key = findingKey(root, Toolchain.toUnix(path), "SyntaxError", message)

					if not seen[key] then
						seen[key] = true
						table.insert(failures, key)
					end
				end
			end
		end
	end

	table.sort(failures)

	return {
		name = "syntax",
		status = if #failures > 0 then "fail" else "pass",
		checked = #files,
		known = 0,
		added = #failures,
		removed = 0,
		durationMs = math.floor((os.clock() - started) * 1000),
		failures = failures,
	}
end

--- One `stylua --check` pass: returns the set of files with a diff. Paths are
--- normalized to slashes and stripped of a leading `.\`, otherwise merging the
--- two passes would find nothing.
local function checkPass(
	root: string,
	binary: string,
	files: { string },
	endings: string
): { [string]: true }
	local failed: { [string]: true } = {}

	for _, chunk in batches(files, BATCH) do
		local args: { string } = { "--check", `--line-endings={endings}` }

		for _, file in chunk do
			table.insert(args, file)
		end

		local ok, result = pcall(process.exec, binary, args, { cwd = root })

		if ok then
			-- The file name ends with a colon and the name itself may contain one
			-- (`C:\...`). Anchoring on `$` does not work here: in `gmatch` `$`
			-- refers to the whole output, not to the line, so not a single match
			-- would go through.
			for path in (result.stdout .. result.stderr):gmatch("Diff in ([^\r\n]+):") do
				local clean = Toolchain.toUnix(path):gsub("^%./", "")
				failed[Toolchain.relative(root, clean)] = true
			end
		end
	end

	return failed
end

--- The format gate. A file counts as unformatted only if it fails both passes:
--- otherwise a CRLF copy of an honest file would land in the baseline.
function Quality.format(root: string, files: { string }, options: Options): GateResult
	const started = os.clock()
	const binary = Toolchain.find(root, "stylua")

	if not binary then return skipped("format", "stylua not found", #files, started) end

	local unix = checkPass(root, binary, files, "Unix")
	local windows = checkPass(root, binary, files, "Windows")

	local current: { [string]: string } = {}

	for path in unix do
		if windows[path] then current[path] = path end
	end

	local known = Baseline.load(root, "format")
	local failures, removed = gateFailures(current, known)

	if options.update then
		Baseline.save(
			root,
			"format",
			(function()
				local keys: { string } = {}

				for path, key in current do
					if not ownFile(path) then table.insert(keys, key) end
				end

				return keys
			end)(),
			{
				"Files that were already unformatted. Regenerate with:",
				"    lune run tools/check.luau --update-baseline",
				"A new file in this list means the gate will fail until it is formatted.",
			}
		)
	end

	local knownCount = 0

	for path in current do
		if known[path] then
			knownCount += 1
		end
	end

	return {
		name = "format",
		status = if #failures > 0 then "fail" else "pass",
		checked = #files,
		known = knownCount,
		added = #failures,
		removed = #removed,
		durationMs = math.floor((os.clock() - started) * 1000),
		failures = failures,
	}
end

--- Generates the sourcemap. The file is in `.gitignore`, so it is always
--- regenerated: 200 ms against the risk of analyzing code against a stale map.
local function ensureSourcemap(root: string, options: Options): (string?, string?)
	if not options.refreshSourcemap and fs.isFile(`{root}/sourcemap.json`) then
		return `{root}/sourcemap.json`, nil
	end

	const rojo = Toolchain.find(root, "rojo")

	if not rojo then return nil, "rojo not found: cannot generate sourcemap.json" end

	local ok, result = pcall(
		process.exec,
		rojo,
		{ "sourcemap", "--include-non-scripts", "--output", "sourcemap.json" },
		{ cwd = root }
	)

	if not ok or not result.ok then
		return nil, `rojo sourcemap failed: {(result and result.stderr) or "unknown error"}`
	end

	return `{root}/sourcemap.json`, nil
end

--- A `luau-lsp analyze --formatter=plain` diagnostic line arrives in two shapes,
--- and the second is easy to lose:
---
---   for the requested file:  `path/file.luau:12:3-5: (W0) Code: message`
---   for one of its deps:    `path/file.luau [game/ReplicatedStorage/...]:12:3-5: (W0) Code: msg`
---
--- The second form is noise: it repeats findings from Crane, Proxy, Signal and the
--- other vendored modules for every file that requires them. So the parse returns
--- the file path, and the gate keeps only the findings whose file is actually
--- being checked.
local function parseDiagnostic(line: string): (string?, string?, string?)
	-- The module path bracket is matched lazily: `]` inside a character class is not
	-- escaped in Luau, and an "everything up to `]`" class cannot be written at all.
	local raw, body = line:match("^(.-%.luau) %[.-%]:%d+:%d+%-%d+:%s*(.*)$")

	if not raw or not body then
		raw, body = line:match("^(.-%.luau):%d+:%d+%-%d+:%s*(.*)$")
	end

	if not raw or not body then return nil, nil, nil end

	-- The severity is wrapped in parentheses: `(W0) TypeError: ...`.
	local code, message = body:match("%(%a%d+%)%s+([%a%d_]+):%s*(.*)$")

	if not code or not message then return nil, nil, nil end

	return Toolchain.toUnix(raw), code, message
end

--- The lint gate. `selene -q -n` prints one line per finding and nothing else:
---
---   path/file.luau:12:7: warning[unused_variable]: message
---
--- which is parsable without a JSON reader. `-n` drops the summary block, whose
--- "0 errors / 3 warnings" lines would otherwise be mistaken for findings.
---
--- The directories are handed over instead of the file list: selene walks them
--- itself, which is one process instead of the twenty a Windows command line full
--- of 800 paths would need. The vendored packages are dropped by `exclude` in
--- `selene.toml`, which is the same list as `Toolchain.VENDORED`.
---
--- selene exits with 1 as soon as it has a finding, so `result.ok` means nothing
--- here and only a failed spawn counts as a broken run.
function Quality.lint(root: string, files: { string }, options: Options): GateResult
	local started = os.clock()
	local binary = Toolchain.find(root, "selene")

	if not binary then return skipped("lint", "selene not found", #files, started) end

	local args: { string } = { "-q", "-n" }

	for _, dir in Toolchain.SOURCE_ROOTS do
		table.insert(args, dir)
	end

	local current: { [string]: string } = {}
	local failures: { string } = {}
	local broken = 0

	local ok, result = pcall(process.exec, binary, args, { cwd = root })

	if not ok then
		broken += 1
	else
		-- Anything on stderr is selene failing to start or to read the config;
		-- its findings all go to stdout.
		for _, line in Toolchain.lines(result.stderr) do
			table.insert(failures, `selene failed: {line}`)
		end

		for _, line in Toolchain.lines(result.stdout) do
			local raw, severity, code, message =
				line:match("^(.-%.luau):%d+:%d+:%s*(%a+)%[(.-)%]:%s*(.*)$")

			if raw and severity and code and message then
				-- `gsub` returns the string and the replacement count; the extra
				-- result is discarded with parentheses.
				local path = Toolchain.relative(root, (Toolchain.toUnix(raw):gsub("^%./", "")))

				current[findingKey(root, path, `{severity}[{code}]`, message)] = path
			end
		end
	end

	table.sort(failures)

	local known = Baseline.load(root, "lint")
	local stale: { string } = {}

	-- The baseline comparison is skipped when selene itself broke: otherwise
	-- empty output would look like "no findings".
	if #failures == 0 then
		local gateList
		gateList, stale = gateFailures(current, known)

		for _, finding in gateList do
			table.insert(failures, finding)
		end
	end

	if options.update then
		local keys: { string } = {}

		-- The `current` key is the finding itself, the value is the file: the order
		-- is exactly like that, otherwise only paths would end up in the baseline.
		for finding, path in current do
			if not ownFile(path) then table.insert(keys, finding) end
		end

		Baseline.save(root, "lint", keys, {
			"Lint findings that were already present. Regenerate with:",
			"    lune run tools/check.luau --update-baseline",
			"A new entry means the gate fails until it is fixed or accepted.",
		})
	end

	local knownCount = 0

	for finding in current do
		if known[finding] then
			knownCount += 1
		end
	end

	return {
		name = "lint",
		status = if #failures > 0 or broken > 0 then "fail" else "pass",
		checked = #files,
		known = knownCount,
		added = #failures,
		removed = #stale,
		durationMs = math.floor((os.clock() - started) * 1000),
		failures = failures,
	}
end

--- The analyze gate. `luau-lsp analyze` always exits with code 0, even with type
--- errors, so the decision is made on the parsed output.
function Quality.analyze(root: string, files: { string }, options: Options): GateResult
	const started = os.clock()
	const binary = Toolchain.find(root, "luau-lsp")

	if not binary then return skipped("analyze", "luau-lsp not found", #files, started) end

	const defs = Toolchain.findDefs(root)

	if not defs then
		return skipped("analyze", "globalTypes.d.luau not found (set LUAU_DEFS)", #files, started)
	end

	local sourcemap, failure = ensureSourcemap(root, options)

	if not sourcemap then
		return skipped("analyze", failure or "sourcemap unavailable", #files, started)
	end

	local current: { [string]: string } = {}
	local failures: { string } = {}
	local broken = 0

	-- Only check the files that were handed to the analyzer themselves: it pulls in
	-- everything else as a dependency and repeats those findings for every file
	-- that requires it.
	local checked: { [string]: boolean } = {}

	for _, file in files do
		checked[Toolchain.relative(root, file)] = true
	end

	for _, chunk in batches(files, BATCH) do
		local args: { string } = {
			"analyze",
			"--formatter=plain",
			`--base-luaurc={root}/.luaurc`,
			`--defs={defs}`,
			`--sourcemap={sourcemap}`,
		}

		for _, file in chunk do
			table.insert(args, file)
		end

		local ok, result = pcall(process.exec, binary, args, { cwd = root })

		if ok then
			if not result.ok then
				broken += 1

				for _, line in Toolchain.lines(result.stderr) do
					table.insert(failures, `luau-lsp failed: {line}`)
				end
			end

			for _, line in Toolchain.lines(result.stdout .. "\n" .. result.stderr) do
				local raw, code, message = parseDiagnostic(line)

				if raw and code and message then
					-- `gsub` returns the string and the replacement count; the extra result is
					-- discarded with parentheses.
					local path = Toolchain.relative(root, (raw:gsub("^%./", "")))

					if checked[path] then current[findingKey(root, path, code, message)] = path end
				end
			end
		else
			broken += 1
		end
	end

	table.sort(failures)

	local known = Baseline.load(root, "analysis")
	local stale: { string } = {}

	-- The baseline comparison is skipped when the analyzer itself broke: otherwise
	-- empty output would look like "no findings".
	if #failures == 0 then
		local gateList
		gateList, stale = gateFailures(current, known)

		for _, finding in gateList do
			table.insert(failures, finding)
		end
	end

	if options.update then
		local keys: { string } = {}

		-- The `current` key is the finding itself, the value is the file: the order is
		-- exactly like that, otherwise only paths would end up in the baseline.
		for finding, path in current do
			if not ownFile(path) then table.insert(keys, finding) end
		end

		Baseline.save(root, "analysis", keys, {
			"Diagnostics that were already present. Regenerate with:",
			"    lune run tools/check.luau --update-baseline",
			"A new entry means the gate fails until it is fixed or accepted.",
		})
	end

	local knownCount = 0

	for finding in current do
		if known[finding] then
			knownCount += 1
		end
	end

	return {
		name = "analyze",
		status = if #failures > 0 or broken > 0 then "fail" else "pass",
		checked = #files,
		known = knownCount,
		added = #failures,
		removed = #stale,
		durationMs = math.floor((os.clock() - started) * 1000),
		failures = failures,
	}
end

--- Runs the gates by name. An empty `only` means every gate.
function Quality.run(root: string, options: Options): { GateResult }
	const files = Toolchain.sources(root)

	local gates: { { name: string, run: (string, { string }, Options) -> GateResult } } = {
		{ name = "syntax", run = Quality.syntax },
		{ name = "format", run = Quality.format },
		{ name = "lint", run = Quality.lint },
		{ name = "analyze", run = Quality.analyze },
	}

	local results: { GateResult } = {}

	for _, gate in gates do
		local wanted = #options.only == 0

		for _, name in options.only do
			if name == gate.name then wanted = true end
		end

		if wanted then table.insert(results, gate.run(root, files, options)) end
	end

	for _, result in results do
		if result.status == "skip" and options.strict then
			result.status = "fail"
			result.failures = { `skipped: {result.skipped}` }
			result.added = 1
		end
	end

	return results
end

--- Human-readable report: one line per gate, findings listed underneath.
function Quality.report(results: { GateResult }): string
	const lines: { string } = {}
	local passed, failed, missing = 0, 0, 0
	local duration = 0

	for _, result in results do
		duration += result.durationMs

		local summary = if result.status == "skip"
			then `skipped: {result.skipped}`
			elseif
				result.added > 0
			then `{result.added} new of {result.checked} checked, {result.known} known`
			else `{result.checked} files clean`

		table.insert(
			lines,
			`{result.status == "pass" and "  ok  " or result.status} {string.format(
				"%-8s",
				result.name
			)} {summary} ({result.durationMs} ms)`
		)

		if result.status == "pass" then
			passed += 1

			-- Baselined findings that no longer reproduce break nothing, but they leave litter
			-- in the file: better to say so right away.
			if result.removed > 0 then
				table.insert(
					lines,
					`       ~ {result.removed} baselined findings are gone, run with --update-baseline to prune`
				)
			end
		elseif result.status == "skip" then
			missing += 1
		else
			failed += 1

			for _, finding in result.failures do
				table.insert(lines, `       - {finding}`)
			end
		end
	end

	table.insert(lines, 1, `{passed} ok, {failed} failed, {missing} skipped ({duration} ms)`)

	return table.concat(lines, "\n")
end

return Quality
