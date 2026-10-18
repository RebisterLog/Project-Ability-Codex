--!strict
--- Shared helpers for skill suites.
---
--- The golden trace is the cheapest regression net a skill can have: the run is
--- deterministic (virtual clock, frames advanced by the test), so the whole
--- effect list can be compared with the text recorded on the day the skill was
--- written. A damage change, a shifted frame or a removed effect shows up as a
--- diff instead of surviving until someone plays the game and notices.
---
--- The repository root is resolved once here rather than passed to every call:
--- four suites call these functions and none of them has a reason to know where
--- the repository lives.

local Root = require("../../tools/SkillHarness/Root")
local Specs = require("../../tools/SkillHarness/Specs")
local fs = require("@lune/fs")
local json = require("../../tools/json")

local Support = {}

Support.root = Root.find()

--- Order matters: the trace is read as a story of the skill, and sorting by
--- frame first keeps "hit on frame 20, then cleanup on frame 30" in that order.
local function order(kind: string): number
	if kind == "parameter" then return 1 end
	if kind == "armor" then return 2 end
	if kind == "stand" then return 3 end
	if kind == "effect" then return 4 end
	if kind == "hitbox" then return 5 end
	if kind == "attack" then return 6 end

	return 7
end

--- One line per recorded effect. Only the fields a test cares about are kept:
--- a golden that stores CFrame coordinates would break on every unrelated tweak
--- of a hitbox offset.
function Support.canonical(world: any): { string }
	local lines: { string } = {}

	-- Entries are wrapped (`kind`, `index`, `data`); the payload lives in `data`.
	for _, record in world.trace.entries do
		local entry = record.data

		if entry.kind == "hitbox" then
			table.insert(lines, `hitbox frame={entry.frame} targets={entry.targets}`)
		elseif entry.kind == "attack" then
			local name = "?"

			if type(entry.victim) == "table" and (entry.victim :: any).instance then
				name = (entry.victim :: any).instance.Name
			end

			table.insert(
				lines,
				`attack frame={entry.frame} target={name} damage={tostring(entry.damage)} stun={tostring(
					entry.stun and entry.stun.Duration
				)} priority={tostring(entry.stun and entry.stun.Priority)}`
			)
		elseif entry.kind == "parameter" then
			table.insert(
				lines,
				`parameter frame={entry.frame} {entry.name}={tostring(entry.value)} {entry.action}`
			)
		elseif entry.kind == "armor" then
			table.insert(lines, `armor frame={entry.frame} {if entry.removed then "off" else "on"}`)
		elseif entry.kind == "effect" then
			table.insert(lines, `effect frame={entry.frame} {entry.name} {entry.action}`)
		elseif entry.kind == "stand" then
			-- `Summon` does nothing else, so this is the only thing its golden
			-- can hold: without it the file would be an empty list that agrees
			-- with every possible implementation.
			table.insert(lines, `stand frame={entry.frame} {entry.action}`)
		end
	end

	-- Entries on the same frame are sorted by kind and then by the line itself:
	-- `table.sort` is not stable, and a golden that reorders itself between runs
	-- would report a diff where nothing changed.
	table.sort(lines, function(a, b)
		local kindA, frameA = a:match("^(%a+) frame=(%d+)")
		local kindB, frameB = b:match("^(%a+) frame=(%d+)")

		-- `tonumber` keeps the type honest: the capture is a string, and casting
		-- it to a number is the kind of lie the analyzer is right to refuse.
		local numberA = tonumber(frameA) or 0
		local numberB = tonumber(frameB) or 0

		if numberA ~= numberB then return numberA < numberB end

		local rankA = order(kindA or "")
		local rankB = order(kindB or "")

		if rankA ~= rankB then return rankA < rankB end

		return a < b
	end)

	return lines
end

local function goldenPath(skill: string): string
	return `{Support.root}/tests/skills/goldens/{skill:gsub("/", "_")}.json`
end

--- The settings a skill is run with: the spec that owns it, the frames, and the
--- targets. Reading the spec from the registry is what keeps `Footrest` off the
--- Undyne skin and `StandBarrage` off the Standless one.
function Support.settings(skill: string, frames: number?, targets: number?): { [string]: any }
	local spec = Specs.owner(Support.root, skill) or "Standless"
	local skins = Specs.skins(Support.root, spec)
	local skin = if table.find(skins, "None") ~= nil then "None" else skins[1] or "None"

	return {
		spec = spec,
		skin = skin,
		targets = targets or 2,
		frames = frames or 60,
	}
end

--- Runs a skill and returns the canonical trace for it.
function Support.capture(skill: string, frames: number?): { string }
	local Harness = require("../../tools/SkillTest")

	const settings = Support.settings(skill, frames)

	-- The world is bound to a local first: a `(expression):method()` statement
	-- directly after another one is ambiguous for the parser, and stylua will
	-- happily glue the two calls into one line that means something else.
	local world = Harness.world(settings)
	local handle = world:skill(skill)

	handle:Activate()
	world:Step(settings.frames)

	return Support.canonical(world)
end

--- Compares a fresh trace with the recorded one. Returns the lines that differ,
--- in both directions, so a report shows what appeared and what vanished.
function Support.compare(skill: string, actual: { string }): { string }
	const path = goldenPath(skill)

	if not fs.isFile(path) then return { `no golden for {skill}, run with --update` } end

	const expected = json.decode(fs.readFile(path)) :: { string }
	const problems: { string } = {}

	for index = 1, math.max(#expected, #actual) do
		const before = expected[index]
		const after = actual[index]

		if before ~= after then
			if before ~= nil then table.insert(problems, `- {before}`) end
			if after ~= nil then table.insert(problems, `+ {after}`) end
		end
	end

	return problems
end

function Support.write(skill: string, lines: { string })
	const path = goldenPath(skill)

	fs.writeDir((path:gsub("[^/\\]+$", "")))
	fs.writeFile(path, json.encode(lines, { pretty = true }))
end

--- Only skills with a recorded trace are compared: adding a skill to the
--- manifest without its golden would fail on the first run for no reason.
function Support.hasGolden(skill: string): boolean
	return fs.isFile(goldenPath(skill))
end

return Support
