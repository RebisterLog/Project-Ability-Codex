--!strict
--- Contract and asset coverage for every combat skill.
---
---   lune run tests/skills/Contract.luau
---
--- One suite instead of eighteen: skills share the same shape, and the defects
--- that matter here are the same everywhere — a missing `DisplayName`, a
--- negative `Cooldown`, an `AttackInfo` that contradicts its own tags, or an
--- asset name that does not exist in the skin (a typo the compiler cannot catch
--- and the game turns into `nil` mid-fight).
---
--- A skill is only checked against the specs that actually list it, read from
--- `src/server/specs/*.luau`: checking `Footrest` against the Undyne skin would
--- assert nothing real and fail on assets that were never meant to be there.
---
--- Loading every skill doubles as the readiness matrix for the harness: every
--- skill on disk has to load and run. A skill that cannot is not "known to be
--- broken", it is a gap in the harness, and the failure says which one.
---
--- There is no allowlist any more because there is nothing left to allow: all
--- seventeen real skills run. A skill that cannot is a new gap, and it fails
--- here the day it is written instead of after someone tries to test it.

local Harness = require("../../tools/SkillTest")
local Specs = require("../../tools/SkillHarness/Specs")
local Support = require("../support/Support")

--- Stun priorities live in `server/Enums.luau`; anything outside the range is
--- a typo like `Enums.Stun.Medium` written as `Enums.Stun.Meduim`.
const STUN_MIN = 0
const STUN_MAX = 30

--- Files under `src/server/skills/` that are not skills. `TEMPLATE.luau` is the
--- skeleton new skills are copied from and is expected to fail to run.
local TEMPLATES = { TEMPLATE = true }

--- Modules a skill requires that the harness deliberately replaces with a stub,
--- with the reason. A stub means part of the skill ran as a no-op, which is only
--- acceptable where the test is not about that part: `Projectile` owns real
--- physics and replication, and a headless fake of it would only look like
--- coverage. Everything else has to resolve for real.
local KNOWN_STUBS: { [string]: { [string]: string } } = {
	["Standless/DualPistols"] = {
		Projectile = "owns travel, replication and the swept surface test",
	},
}

local passed = 0
local failures: { string } = {}

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		return
	end

	table.insert(failures, if detail ~= nil then `{name} — {detail}` else name)
end

--- A skill that hits declares its damage somewhere, but not always in the same
--- place: `Punch` puts it in `AttackInfo.Damage`, `Grab` keeps a separate
--- `Throw.Damage` for the throw phase. Searching the whole module for a numeric
--- `Damage` catches both without encoding every shape into this suite.
local function declaresDamage(data: { [string]: any }, depth: number): boolean
	if depth <= 0 then return false end

	for key, value in data do
		if key == "Damage" and type(value) == "number" then return true end

		if type(value) == "table" and declaresDamage(value, depth - 1) then return true end
	end

	return false
end

--- Checks one skill module. Returns nothing: failures accumulate, so a broken
--- skill reports every problem it has, not just the first.
local function checkData(name: string, data: { [string]: any })
	local label = `{name}: `

	check(
		`{label}DisplayName`,
		type(data.DisplayName) == "string" and data.DisplayName ~= "",
		tostring(data.DisplayName)
	)

	if data.Cooldown ~= nil then
		check(`{label}Cooldown is a number`, type(data.Cooldown) == "number", type(data.Cooldown))

		if type(data.Cooldown) == "number" then
			check(`{label}Cooldown is not negative`, data.Cooldown >= 0, tostring(data.Cooldown))
		end
	end

	if data.SkillCharacters ~= nil then
		check(`{label}SkillCharacters is a table`, type(data.SkillCharacters) == "table")

		for _, tag in data.SkillCharacters do
			check(`{label}tag '{tag}' is a string`, type(tag) == "string", type(tag))
		end
	end

	-- A skill that declares itself blockable has to say how a block is handled:
	-- the tags are read by other systems, so an empty `Block` contradicts them.
	if data.AttackInfo ~= nil then
		local info = data.AttackInfo

		check(`{label}declares damage`, declaresDamage(data, 4), "no numeric Damage anywhere")

		if info.Damage ~= nil then
			check(
				`{label}AttackInfo.Damage is a number`,
				type(info.Damage) == "number",
				type(info.Damage)
			)
		end

		if info.Stun ~= nil then
			check(
				`{label}Stun.Priority is a number`,
				type(info.Stun.Priority) == "number",
				type(info.Stun.Priority)
			)

			if type(info.Stun.Priority) == "number" then
				check(
					`{label}Stun.Priority within Enums.Stun`,
					info.Stun.Priority >= STUN_MIN and info.Stun.Priority <= STUN_MAX,
					tostring(info.Stun.Priority)
				)
			end

			check(
				`{label}Stun.Duration is a number`,
				type(info.Stun.Duration) == "number",
				type(info.Stun.Duration)
			)
		end

		for _, tag in data.SkillCharacters or {} do
			if tag == "Blockable" then
				check(
					`{label}tag Blockable has Block info`,
					type(info.Block) == "table",
					tostring(type(info.Block))
				)
			end
		end
	end
end

local index = Specs.index(Support.root)
local names = Harness.skills()

for _, name in names do
	if TEMPLATES[name] then
		passed += 1
		continue
	end

	local specs = index[name]

	-- A skill no spec lists is dead code: nobody can ever activate it.
	check(`{name} is used by a spec`, specs ~= nil, `no spec lists this skill`)

	if specs == nil then continue end

	for _, spec in specs do
		-- One target is enough: this suite is about the contract and the asset
		-- names, and `tests/skills/<Skill>.luau` is where a hit is worth counting.
		local settings = Support.settings(name, 60, 1)

		settings.spec = spec

		local madeWorld, world = pcall(Harness.world, settings)

		if not madeWorld then
			check(`{name} loads with {spec}`, false, tostring(world))
			continue
		end

		local casted = world :: any
		local ok, skill = pcall(function()
			return casted:skill(name)
		end)

		if not ok then
			check(`{name} loads with {spec}`, false, tostring(skill))
			continue
		end

		local label = `{name} ({spec})`
		local handle = skill :: any

		checkData(label, handle.Data)

		-- Assets are only touched once the skill runs, and a skill may read them
		-- only inside a frame callback, so the run is what surfaces the names.
		local ran, failure = pcall(function()
			handle:Activate()
			casted:Step(60)
		end)

		check(`{label} runs under the harness`, ran, tostring(failure))

		if not ran then continue end

		local missing = casted:missingAssets()
		local stubbed = casted:missingModules()

		check(
			`{label} assets resolve in the {spec} skin`,
			#missing == 0,
			table.concat(missing, ", ")
		)

		-- A stubbed module is a part of the skill that ran but was not checked:
		-- the suite passes while something inside it is a no-op. Only a stub
		-- with a written reason is allowed.
		local accepted = KNOWN_STUBS[name] or {}
		local unexpected: { string } = {}

		for _, stub in stubbed do
			local module = stub:match("([^%.]+)$") or stub

			if accepted[module] == nil then table.insert(unexpected, stub) end
		end

		check(
			`{label} needs no undocumented stubbed modules`,
			#unexpected == 0,
			table.concat(unexpected, ", ")
		)
	end
end

-- Every spec entry has to point at a file that exists: a typo in the path means
-- the skill silently never loads in game.
local onDisk: { [string]: boolean } = {}

for _, path in names do
	onDisk[path] = true
end

for skill, specs in index do
	check(
		`spec entry '{skill}' points at a skill`,
		onDisk[skill] == true,
		`listed by {table.concat(specs, ", ")}`
	)
end

print(`[tests.skills.Contract] passed: {passed}, failed: {#failures}`)

if #failures > 0 then error(table.concat(failures, "\n"), 0) end
