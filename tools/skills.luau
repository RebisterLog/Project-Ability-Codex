--!strict
--- Working with combat skills outside Studio.
---
---   lune run tools/skills.luau                       list every skill and whether it loads
---   lune run tools/skills.luau Punch                 run one skill and print its trace
---   lune run tools/skills.luau inspect Standless/Uppercut   detailed trace, frame by frame
---
--- Options:
---   --spec=Standless   which spec provides the assets
---   --skin=None        which skin within that spec
---   --targets=2        how many dummies stand in front of the caster
---   --frames=60        how far to advance time
---   --interrupt=10     interrupt the skill after N frames (0 disables)
---
--- `inspect` is what a playtest used to be for: it prints every hitbox, hit,
--- parameter change and effect with the frame it happened on, as text.

local Harness = require("./SkillTest")
local Root = require("./SkillHarness/Root")
local Specs = require("./SkillHarness/Specs")

local process = require("@lune/process")

local function option(name: string, fallback: string): string
	for _, arg in process.args do
		if arg:sub(1, #name + 1) == `{name}=` then return arg:sub(#name + 2) end
	end

	return fallback
end

local function flag(name: string): boolean
	for _, arg in process.args do
		if arg == `--{name}` then return true end
	end

	return false
end

--- The spec decides whose assets a skill loads. Most skills are shared and used
--- by several specs, so the default comes from the spec that actually owns the
--- skill: asking for `Standless` while running `StandBarrage` reports missing
--- assets the game never looks for.
local function options(skill: string?): { [string]: any }
	local root = Root.find()
	local chosen = option("spec", "")

	if chosen == "" and skill ~= nil then chosen = Specs.owner(root, skill) or "Standless" end

	local spec = if chosen == "" then "Standless" else chosen
	local skin = option("skin", "")

	if skin == "" then
		-- A spec without a `None` skin still has to load; the first skin it
		-- defines is a better guess than a name that does not exist.
		local skins = Specs.skins(root, spec)

		skin = if table.find(skins, "None") ~= nil then "None" else skins[1] or "None"
	end

	return {
		spec = spec,
		skin = skin,
		targets = tonumber(option("targets", "1")) or 1,
		frames = tonumber(option("frames", "60")) or 60,
		interrupt = tonumber(option("interrupt", "0")) or 0,
	}
end

--- One trace line per recorded effect. Vector-like values print as-is: the
--- point is to read the sequence, not to parse coordinates.
local function describe(entry: { [string]: any }): string
	if entry.kind == "hitbox" then
		return `frame {entry.frame}: hitbox, {entry.targets} target(s)`
	end

	if entry.kind == "attack" then
		local name = if type(entry.victim) == "table"
			then ` ({tostring(
				(entry.victim :: any).instance and (entry.victim :: any).instance.Name
			)})`
			else ""

		return `frame {entry.frame}: attack{name}, damage {tostring(entry.damage)}, stun {tostring(
			entry.stun and entry.stun.Duration
		)}`
	end

	if entry.kind == "parameter" then
		return `frame {entry.frame}: parameter {entry.name} = {tostring(entry.value)} ({entry.action})`
	end

	if entry.kind == "effect" then return `frame {entry.frame}: {entry.name} {entry.action}` end

	if entry.kind == "armor" then
		return `frame {entry.frame}: armor {if entry.removed then "off" else "on"}`
	end

	if entry.kind == "asset" then
		return `asset {entry.name} {if entry.found then "found" else "MISSING"}`
	end

	return `frame {entry.frame}: {entry.kind}`
end

local function run(settings: { [string]: any }, name: string, detailed: boolean)
	local world = Harness.world(settings)
	local skill = world:skill(name)

	print(`{name}: {skill.Data.DisplayName}, cooldown {tostring(skill.Data.Cooldown)}`)

	skill:Activate()

	-- `settings.interrupt or settings.frames` would be wrong here: in Lua `0` is
	-- true, so the common case of "no interrupt" would step zero frames and
	-- print an empty trace for every skill.
	if settings.interrupt > 0 then
		world:Step(settings.interrupt)

		skill.Active = true
		skill:Interrupt()
	end

	world:Step(settings.frames)

	for _, entry in world.trace.entries do
		if detailed or entry.kind ~= "asset" then print(describe(entry)) end
	end

	local missing = world:missingAssets()

	if #missing > 0 then
		print("")
		print(`missing assets: {table.concat(missing, ", ")}`)
	end

	local unresolved = world:missingModules()

	if #unresolved > 0 then print(`stubbed modules: {table.concat(unresolved, ", ")}`) end

	print("")
	print(`attack(s): {#world.trace:attacks()}, hitbox(s): {#world.trace:hitboxes()}`)
end

--- The loader prefixes the message with the file it came from, and a failure
--- inside a frame callback carries a whole traceback after it. Neither belongs
--- in a one-line-per-skill report, and without this a skill could print a stack
--- where the reason should be.
local function firstLine(reason: string): string
	const message = reason:match("^[^\n]*") or reason

	return (message:gsub("^.-:%d+: ", ""))
end

--- Listing loads every skill in turn: a skill that cannot be loaded in the
--- harness is a gap to fill, and saying so beats failing at the first import.
---
--- Each skill is tried with the spec that owns it, which is the only pairing the
--- game ever uses. `--spec` still wins, for checking a skill against a skin it is
--- not normally paired with.
local function list()
	const names = Harness.skills()
	const frames = tonumber(option("frames", "60")) or 60

	local ready = 0
	local templates = 0

	for _, name in names do
		local reason: string? = nil

		-- `options` resolves the owning spec on its own; passing the name is what
		-- makes that lookup happen, and an explicit `--spec` still wins.
		-- `pcall` returns several values, so they are unpacked into two names: a
		-- single binding would keep only the success flag and drop the message.
		local madeWorld, world = pcall(Harness.world, options(name))

		if not madeWorld then
			reason = tostring(world)
		else
			local casted = world :: any
			local ran, failure = pcall(function()
				local skill = casted:skill(name)

				skill:Activate()
				casted:Step(frames)
			end)

			if ran then
				ready += 1
			else
				reason = tostring(failure)
			end
		end

		if name:upper() == name then
			-- A file named in capitals is not a skill: `TEMPLATE.luau` is the
			-- skeleton new skills are copied from and is expected to fail.
			templates += 1
			print(`--  {name}: template, not a skill`)
		elseif reason then
			print(`--  {name}: {firstLine(reason)}`)
		else
			print(`ok  {name}`)
		end
	end

	print("")
	local summary = `{ready} of {#names - templates} skills run under the harness`
	print(summary)
end

local args = process.args

if args[1] == "list" then
	list()
	return
end

local name = args[1]

if name == nil or flag("help") then
	print(
		"usage: lune run tools/skills.luau [list|<Skill>] [inspect] [--spec=] [--skin=] [--targets=] [--frames=] [--interrupt=]"
	)
	return
end

run(options(name), name, args[2] == "inspect")
