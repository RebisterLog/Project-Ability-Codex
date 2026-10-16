--!strict
--- Finding the repository root and project files.
---
--- It lives in its own file rather than in `init.luau` because of Lune: in a
--- module that is a directory entry point (`SkillHarness/init.luau`), the path
--- `require("../X")` resolves from the directory one level up, so `../Toolchain`
--- escapes `tools`. An ordinary module file resolves fine.

local Toolchain = require("../Toolchain")
local fs = require("@lune/fs")

local Root = {}

--- Repository root. It is looked up via `default.project.json`, so launching
--- from any directory gives the same result.
function Root.find(): string
	return Toolchain.findRoot()
end

--- Recursive list of `.luau` files relative to the root: the paths come back
--- without the root prefix so they can be compared between machines.
function Root.scripts(relative: string): { string }
	local root = Root.find()
	local vendored = Toolchain.vendoredSet(root)
	local files: { string } = {}

	for _, path in Toolchain.scripts(`{root}/{relative}`, vendored) do
		table.insert(files, Toolchain.relative(root, path))
	end

	return files
end

--- Whether a file exists at a relative path: used to avoid loading a skin that
--- is not there.
function Root.has(relative: string): boolean
	return fs.isFile(`{Root.find()}/{relative}`)
end

return Root
