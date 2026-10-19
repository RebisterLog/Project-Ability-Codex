--!strict
--- Finding the external checking tools: where the binaries live and what to run
--- them on.
---
--- Gates must not fail because a machine is set up differently, so every tool is
--- looked up through a list of directories, and a missing binary means the gate is
--- skipped with a warning rather than failing. The explicit requirement
--- (`Quality --strict`) turns a skip into an error: that is how CI tells
--- "nothing to check with" apart from "checked and clean".
---
--- Directories are searched in this order:
---   1. `PAC_TOOLS_DIR` — an explicit override from the environment;
---   2. the directory next to the running `lune` — that is how this machine is
---      laid out (`C:\Users\RebisterLog\Luau`), and downloaded binaries go there
---      too;
---   3. `<root>/.tools` — a local cache that could be committed to the repository,
---      but is in `.gitignore` by default;
---   4. `PATH`.
---
--- The Roblox global definitions are only needed by the analyzer: without them
--- `luau-lsp analyze` treats `game`, `Vector3` and `CFrame` as unknown and reports
--- false errors on every line. They ship next to the Luau binaries in the release
--- archive, and the path is overridable through `LUAU_DEFS`.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Toolchain = {}

--- Repository root marker: without it a directory does not count as the root.
const ROOT_MARKER = "default.project.json"

--- Vendored packages. We neither format nor analyze them: they arrived from
--- outside, edits in them are not ours, and findings in them are not actionable.
--- The list comes from the commit that moved the pre-committed code to `const`:
--- it enumerates exactly what was deliberately left untouched.
const VENDORED = {
	"src/shared/packages/Roact",
	"src/shared/packages/Fusion",
	"src/shared/packages/Cmdr",
	"src/shared/packages/ForgeVFX",
	"src/shared/packages/Lapis",
	"src/shared/packages/Janitor",
	"src/shared/packages/roact-spring",
	"src/shared/packages/Sequencer",
	"src/shared/packages/SkillConstructor",
	"src/shared/packages/Signal.luau",
	"src/shared/packages/Crane/packages",
}

--- Directories holding the sources every gate checks. Exported rather than kept
--- local: the lint gate hands selene the directories instead of the file list,
--- and a second copy of these three strings would drift.
Toolchain.SOURCE_ROOTS = { "src", "tools", "tests" }

--- Windows paths arrive with backslashes, while the baseline and the report need
--- paths that are identical on any machine.
function Toolchain.toUnix(path: string): string
	return (path:gsub("\\", "/"))
end

--- Splits a path into parts without caring about the separator: works with both
--- Rojo slashes and Windows backslashes.
function Toolchain.split(path: string): { string }
	const parts: { string } = {}
	local rest = path

	while true do
		const head = rest:match("^[^/\\]+") :: string?

		if not head then break end

		table.insert(parts, head)
		rest = rest:sub(#head + 1):gsub("^[/\\]+", "")
	end

	return parts
end

--- Walks up from `start` until it finds `default.project.json`. `cwd` can be deep
--- in the tree or in an unrelated directory, while the gates must work from the
--- root.
function Toolchain.findRoot(start: string?): string
	const fromEnv = process.env.PAC_ROOT

	if fromEnv and fromEnv ~= "" and fs.isFile(`{fromEnv}/{ROOT_MARKER}`) then
		return Toolchain.toUnix(fromEnv):gsub("/+$", "")
	end

	local current = Toolchain.toUnix(start or process.cwd):gsub("/+$", "")

	while true do
		if fs.isFile(`{current}/{ROOT_MARKER}`) then return current end

		local parts = Toolchain.split(current)

		if #parts <= 1 then break end

		table.remove(parts)
		current = table.concat(parts, "/")
	end

	return Toolchain.toUnix(start or process.cwd):gsub("/+$", "")
end

--- Directory of the running `lune`. Needed so the other Luau binaries can sit
--- next to it: they normally get installed as one bundle.
---
--- `process.platform` does not exist in Lune, so the OS is determined by probing:
--- `where` first (Windows), then `command -v` through the shell (Unix).
function Toolchain.luneDir(): string?
	local lookups = {
		{ command = "where", args = { "lune" } },
		{ command = "sh", args = { "-c", "command -v lune" } },
	}

	for _, lookup in lookups do
		local ok, result = pcall(process.exec, lookup.command, lookup.args, { cwd = process.cwd })

		if ok and result.ok then
			const found = result.stdout:match("^%s*([^\r\n]+)") :: string?

			if found and found ~= "" then
				const path = Toolchain.toUnix(found)
				const parts = Toolchain.split(path)

				if #parts > 1 then
					table.remove(parts)
					return table.concat(parts, "/")
				end
			end
		end
	end

	return nil
end

--- Directories to search for binaries in, in priority order.
function Toolchain.searchDirs(root: string): { string }
	const dirs: { string } = {}

	const fromEnv = process.env.PAC_TOOLS_DIR
	if fromEnv and fromEnv ~= "" then table.insert(dirs, Toolchain.toUnix(fromEnv)) end

	const luneDir = Toolchain.luneDir()
	if luneDir then table.insert(dirs, luneDir) end

	table.insert(dirs, `{root}/.tools`)

	-- Directories from `PATH`: otherwise a binary reachable through `PATH` is never
	-- found.
	for part in tostring(process.env.PATH or ""):gmatch("[^;]+") do
		table.insert(dirs, Toolchain.toUnix(part))
	end

	return dirs
end

--- Path to a binary, or `nil` when it is in none of the directories. Presence is
--- checked by running it: a file with the wrong name or a stub on `PATH` must not
--- pass for the tool.
---
--- The probe tries `--version` first, then `--help`: `luau-compile` has no
--- `--version` flag and exits with code 1 even though the binary is fine.
function Toolchain.find(root: string, name: string): string?
	local probes = { { "--version" }, { "--help" } }

	for _, dir in Toolchain.searchDirs(root) do
		for _, candidate in { name, `{name}.exe` } do
			const path = `{dir}/{candidate}`

			if fs.isFile(path) then
				for _, probe in probes do
					local ok, result = pcall(process.exec, path, probe, { cwd = root })

					if ok and result.ok then return path end
				end
			end
		end
	end

	return nil
end

--- Path to the Roblox global definitions: without them the analyzer does not know
--- `game`, `Vector3`, `Instance` and floods the output with false errors.
function Toolchain.findDefs(root: string): string?
	const fromEnv = process.env.LUAU_DEFS

	if fromEnv and fromEnv ~= "" and fs.isFile(fromEnv) then return Toolchain.toUnix(fromEnv) end

	for _, dir in Toolchain.searchDirs(root) do
		const path = `{dir}/globalTypes.d.luau`

		if fs.isFile(path) then return path end
	end

	return nil
end

--- Recursive `.luau` collection over a directory. Lune has no `fs.scandir`, so
--- the walk is ours — which is exactly why it can prune the vendored packages.
function Toolchain.scripts(dir: string, skip: { [string]: boolean }?): { string }
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

	table.sort(found)

	return found
end

--- Splits text into lines. A string cannot be iterated as a sequence in Luau, and
--- `gmatch` stays silent on empty text — and tool output may well be empty, so
--- that matters here.
function Toolchain.lines(text: string): { string }
	const result: { string } = {}
	local rest = (text:gsub("\r\n", "\n"):gsub("\r", "\n"))

	while true do
		local line = rest:match("^([^\n]*)\n")

		if not line then break end

		local trimmed = line:gsub("%s+$", "")

		if trimmed ~= "" then table.insert(result, trimmed) end

		rest = rest:sub(#line + 2)
	end

	return result
end

--- Prunes the vendored packages: paths are already slash-normalized.
function Toolchain.vendoredSet(root: string): { [string]: boolean }
	const set: { [string]: boolean } = {}

	for _, path in VENDORED do
		set[`{root}/{path}`] = true
	end

	return set
end

--- Every source the gates check: all of `src` (minus the vendored parts) plus our
--- own `tools` and `tests`.
function Toolchain.sources(root: string): { string }
	const vendored = Toolchain.vendoredSet(root)
	const files: { string } = {}

	for _, dir in Toolchain.SOURCE_ROOTS do
		for _, path in Toolchain.scripts(`{root}/{dir}`, vendored) do
			table.insert(files, path)
		end
	end

	return files
end

--- Path relative to the root: machine-specific absolute paths must not leak into
--- the baseline and the report, otherwise reports cannot be compared across
--- machines.
---
--- The comparison is case-insensitive, and the trailing slashes on the root are
--- trimmed: the analyzer prints paths with a differently cased drive letter and
--- without a trailing slash, and without those two fixes every path would look
--- "foreign".
function Toolchain.relative(root: string, path: string): string
	const unix = Toolchain.toUnix(path)
	const prefix = Toolchain.toUnix(root):gsub("/+$", "") .. "/"

	if unix:sub(1, #prefix):lower() == prefix:lower() then return unix:sub(#prefix + 1) end

	return unix
end

return Toolchain
