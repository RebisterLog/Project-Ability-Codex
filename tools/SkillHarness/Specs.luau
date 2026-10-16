--!strict
--- Which spec owns which skill, read from `src/server/specs/*.luau`.
---
---   local Specs = require("../tools/SkillHarness/Specs")
---   Specs.owner(root, "StandBarrage")   --> "StarPlatinum"
---
--- The spec modules are the source of truth for this, and reading them beats
--- keeping a list in the harness: a skill added to a spec is immediately known,
--- and a skill listed twice is immediately visible.
---
--- Why it matters: a skill only ever loads with the assets of the spec that owns
--- it. `StandBarrage` reaches for `Assets.Stand.*`, which the Standless skin does
--- not have, so testing it against the wrong spec reports a missing asset for a
--- file the game never asks for.

local Loader = require("./Loader")
local Roblox = require("./Roblox")
local Services = require("./Services")
local fs = require("@lune/fs")

local Specs = {}

--- Spec modules are Roblox modules like any other: they call `game:GetService`
--- and `require` at the top level, so they go through the loader rather than
--- through Lune's `require`.
local function environment(): { [string]: any }
	const services = Roblox.services()

	local env: { [string]: any } = {
		game = {
			GetService = function(_self, name)
				return (services :: any)[name]
			end,
		},
		require = function()
			return Services.stub()
		end,
	}

	for name, datatype in Roblox.Datatypes do
		env[tostring(name)] = datatype
	end

	return env
end

--- `"@Specs/Standless/Footrest"` and `"~/skills/Punch"` are both reduced to the
--- path the harness takes after `src/server/skills/`.
local function skillName(source: any): string
	local name = tostring(source)

	if name:sub(1, 7) == "@Specs/" then
		name = name:sub(8)
	elseif name:sub(1, 9) == "~/skills/" then
		name = name:sub(10)
	end

	return (name:gsub("%.luau$", ""))
end

--- Skills of every spec, keyed by skill name. A skill shared by several specs
--- lists all of them, sorted, because the order files come back in is not the
--- order anyone wants to read.
function Specs.index(root: string): { [string]: { string } }
	const index: { [string]: { string } } = {}
	const env = environment()
	const dir = `{root}/src/server/specs`

	if not fs.isDir(dir) then return index end

	for _, path in fs.readDir(dir) do
		if path:sub(-5) ~= ".luau" then continue end

		local specName = path:gsub("%.luau$", "")
		local ok, data = pcall(Loader.file, env, `{dir}/{path}`)

		if not ok or type(data) ~= "table" or type(data.Skills) ~= "table" then continue end

		for _, source in (data :: any).Skills do
			local name = skillName(source)

			index[name] = index[name] or {}
			table.insert(index[name], specName)
		end
	end

	for _, specs in index do
		table.sort(specs)
	end

	return index
end

--- The spec to load a skill with. The first one that owns it, since a shared
--- skill has several owners and any of them loads the same source.
function Specs.owner(root: string, skill: string): string?
	local specs = Specs.index(root)[skill]

	if specs == nil or #specs == 0 then return nil end

	return specs[1]
end

--- Skins a spec defines, from `src/shared/configs/Skins/<Spec>/`. Used to pick a
--- skin that exists instead of assuming `"None"` is always there.
function Specs.skins(root: string, spec: string): { string }
	local dir = `{root}/src/shared/configs/Skins/{spec}`

	if not fs.isDir(dir) then return {} end

	local skins: { string } = {}

	for _, path in fs.readDir(dir) do
		if path:sub(-5) == ".luau" then table.insert(skins, (path:gsub("%.luau$", ""))) end
	end

	table.sort(skins)

	return skins
end

return Specs
