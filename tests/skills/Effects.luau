--!strict
--- Every effect name a server script sends to the client must exist.
---
---   lune run tests/skills/Effects.luau
---
--- This is the one class of mistake the headless harness cannot see. The client
--- resolves an effect by name against the module scripts in `src/shared/effects`:
---
---     function VFXService:StartEffect(name, ...)
---         if not self.Effects[name] then
---             Crane.Utils.Log(script.Name, `Can't find VFX with name {name}`, "error")
---             return
---         end
---
--- An unknown name is not an exception. It is a line in the output log, no effect,
--- and a skill that looks like it works. The harness records whatever string it is
--- handed, so a typo here passes every behavioural test there is; only reading the
--- source catches it.
---
--- The valid names are the file names, so the check needs nothing but the
--- repository: rename `EmitFolder.luau` and this fails on every skill using it,
--- which is the other half of the guarantee.

local Source = require("../support/Source")
local fs = require("@lune/fs")

local ROOT = require("../../tools/SkillHarness/Root").find()
local METHODS = { "StartEffect", "StopEffect", "StartEffectExcept" }

local passed = 0
local failures: { string } = {}

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		return
	end

	table.insert(failures, if detail ~= nil then `{name} — {detail}` else name)
end

--- Names the client will resolve: one per module script under `src/shared/effects`,
--- because that folder is what `VFXService.onStart` walks with `QueryDescendants`.
local function effectNames(): { [string]: boolean }
	local names: { [string]: boolean } = {}
	local dir = `{ROOT}/src/shared/effects`

	if not fs.isDir(dir) then return names end

	local function walk(current: string)
		for _, entry in fs.readDir(current) do
			local path = `{current}/{entry}`

			if fs.isDir(path) then
				walk(path)
			elseif entry:sub(-5) == ".luau" then
				names[entry:sub(1, #entry - 5)] = true
			end
		end
	end

	walk(dir)

	return names
end

local valid = effectNames()

check(
	"the effects folder has modules",
	next(valid) ~= nil,
	"src/shared/effects is empty or missing"
)

--- The server signature is `StartEffect(players, name, ...)`, so the name is the
--- second argument. The client takes the name first, but it only ever forwards a
--- name off the packet, so there is nothing to check there.
for _, path in Source.files("src/server") do
	local source = Source.read(path)

	for _, call in Source.calls(source, METHODS) do
		local name = (call.arguments[2] or ""):match('^%s*"([^"]*)"%s*$')

		if name ~= nil then
			check(
				`{path}:{Source.lineAt(source, call.index)} effect '{name}' exists`,
				valid[name] == true,
				`no module src/shared/effects/{name}.luau`
			)
		end
	end
end

print(`[tests.skills.Effects] passed: {passed}, failed: {#failures}`)

if #failures > 0 then error(table.concat(failures, "\n"), 0) end
