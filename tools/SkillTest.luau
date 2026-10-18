--!strict
--- Entry point for static skill tests.
---
---   local Harness = require("../../tools/SkillTest")
---
---   local world = Harness.world({ spec = "Standless", skin = "None", targets = 2 })
---   local skill = world:skill("Standless/Uppercut")
---
---   skill:Activate()
---   world:Step(40)
---
--- What gets substituted: the Roblox environment (`game`, `task`, `Instance`,
--- `CFrame`), the Crane services (`CombatService`, `VFXService`,
--- `StandService`) and the `Skill` class. What stays real: the skill source,
--- the skin config with its assets, the character parameter table and `Enums`.
---
--- The point is to avoid launching a playtest just to check a single frame:
--- the skill runs to completion, every one of its calls lands in the log, and
--- the assertions inspect that log. What the skill does is readable as text.
---
--- This lives in its own file rather than in `SkillHarness/init.luau` because
--- of a Lune quirk: in a directory module's entry point a relative `require`
--- resolves from the parent directory, so neither `./World` nor
--- `../Toolchain` can find its siblings.

local Root = require("./SkillHarness/Root")
local World = require("./SkillHarness/World")

local Harness = {}

--- Types needed in the test signatures.
export type World = any
export type Trace = any

--- Builds the world for a single run.
---
--- `spec` and `skin` pick the asset config, `targets` is how many targets stand
--- in front of the fighter. Those are exactly what `CombatService:Hitbox`
--- returns.
function Harness.world(options: { [string]: any }?): any
	-- The type is spelled out: `options or {}` widens to a union, and writing
	-- into that is rejected by the analyzer as "unknown field".
	const settings: { [string]: any } = options or {}

	settings.root = settings.root or Root.find()

	return World.new(settings)
end

--- Skills that can be loaded: the list feeds `--list` and is the way to check
--- that a new skill was not forgotten.
function Harness.skills(): { string }
	local list: { string } = {}

	for _, path in Root.scripts("src/server/skills") do
		local name = path:gsub("^src/server/skills/", ""):gsub("%.luau$", "")
		table.insert(list, name)
	end

	table.sort(list)

	return list
end

return Harness
