--!strict
--- Storage of the findings the gates already know: what is in the code today and
--- is not a regression.
---
--- The analyze gate and the format gate cannot be strict right away: the
--- repository carries 183 lint findings and 33 unformatted files, so demanding
--- zero means demanding someone else's work in the very first commit. Therefore
--- findings are diffed against a baseline: new is an error, old is not.
---
--- The file format is one line per finding, with `#` comments on top. Keys are
--- sorted and normalized, otherwise reordering report lines would show up as a
--- phantom baseline change.

local Toolchain = require("./Toolchain")
local fs = require("@lune/fs")

local Baseline = {}

--- Where the baselines live. Next to the tests rather than in `tools`, because
--- this is gate data, not gate code.
const DIRECTORY = "tests/baseline"

--- Directory of the file for `writeDir`: Lune does not create intermediate
--- directories.
local function directoryOf(path: string): string
	local index = path:match("^(.*)[/\\][^/\\]+$") :: string?

	return index or "."
end

function Baseline.path(root: string, name: string): string
	return `{root}/{DIRECTORY}/{name}.txt`
end

--- Reads a baseline. A missing file is an empty baseline, not an error: that
--- way the first run on a clean checkout does not crash, it just starts at zero.
function Baseline.load(root: string, name: string): { [string]: true }
	const set: { [string]: true } = {}
	const path = Baseline.path(root, name)

	if not fs.isFile(path) then return set end

	-- Iterating an array yields the first variable, not the value: the line would
	-- arrive as a number and `line:sub` would blow up.
	for _, line in Toolchain.lines(fs.readFile(path)) do
		if line:sub(1, 1) ~= "#" then set[line] = true end
	end

	return set
end

--- Rewrites the baseline as a sorted list. The header comment survives the
--- rewrite, otherwise the next run would not explain what the file means.
function Baseline.save(root: string, name: string, keys: { string }, header: { string }?)
	const path = Baseline.path(root, name)

	fs.writeDir(directoryOf(path))

	local lines: { string } = {}

	local comments: { string } = header or {}

	for _, line in comments do
		table.insert(lines, `# {line}`)
	end

	local sorted = table.clone(keys)
	table.sort(sorted)

	for _, key in sorted do
		table.insert(lines, key)
	end

	fs.writeFile(path, table.concat(lines, "\n") .. "\n")
end

--- The "now against the baseline" difference. `added` is what makes the gate
--- fail, `removed` is what you can write into the new baseline as fixed.
function Baseline.diff(
	current: { [string]: string },
	known: { [string]: true }
): {
	added: { string },
	removed: { string },
}
	local added: { string } = {}
	local removed: { string } = {}

	for key in current do
		if not known[key] then table.insert(added, key) end
	end

	for key in known do
		if not current[key] then table.insert(removed, key) end
	end

	table.sort(added)
	table.sort(removed)

	return { added = added, removed = removed }
end

return Baseline
