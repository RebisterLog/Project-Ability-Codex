--!strict
--- Test for the `Standless/Footrest` skill.
---
---   lune run tests/skills/Footrest.luau
---
--- Footrest differs from Uppercut in the ways worth pinning down: the hitbox
--- opens on frame 25 and stays open until 30, the swing effect starts a frame
--- earlier (24), and each victim gets their own effect and animation rather than
--- one for the caster.
---
--- "World" means one run: two tests in the same process share nothing.

local Harness = require("../../tools/SkillTest")

local passed = 0
local failures: { string } = {}

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		return
	end

	table.insert(failures, if detail ~= nil then `{name} — {detail}` else name)
end

local function equal(name: string, actual: any, expected: any, detail: string?)
	local message = `expected {tostring(expected)}, got {tostring(actual)}`

	check(name, actual == expected, if detail then `{detail}: {message}` else message)
end

local function scenario(targets: number, frames: number): any
	local world = Harness.world({ spec = "Standless", skin = "None", targets = targets })
	local skill = world:skill("Standless/Footrest")

	skill:Activate()
	world:Step(frames)

	return world, skill
end

-- CONTRACT ------------------------------------------------------------------

do
	local world = Harness.world({ spec = "Standless", skin = "None" })
	local skill = world:skill("Standless/Footrest")
	local data = skill.Data

	equal("DisplayName", data.DisplayName, "Footrest")
	equal("Cooldown", data.Cooldown, 1)
	equal("AttackInfo.Damage", data.AttackInfo.Damage, 15)

	-- The kick staggers harder and longer than an uppercut: that difference is
	-- the reason the skill exists, and it lives in two numbers.
	equal("Stun.Priority is Heavy", data.AttackInfo.Stun.Priority, 30)
	equal("Stun.Duration", data.AttackInfo.Stun.Duration, 1.5)

	-- BlockBreak is explicitly false here, while Uppercut sets it to true. The
	-- distinction is easy to lose in a copy-paste.
	equal("Block.Break is false", data.AttackInfo.Block.BlockBreak, false)
	equal("Block.PerfectBlockable is false", data.AttackInfo.Block.PerfectBlockable, false)

	local unresolved = world:missingModules()
	equal("no unresolved modules", #unresolved, 0, table.concat(unresolved, ", "))
end

-- ASSETS --------------------------------------------------------------------

do
	local world = scenario(1, 50)

	local missing = world:missingAssets()
	equal("all skin assets resolve", #missing, 0, table.concat(missing, ", "))
end

-- TIMING --------------------------------------------------------------------

do
	local world = scenario(2, 50)
	local hitboxes = world.trace:hitboxes()

	-- `{25, fn, 30}` in the source: six frames of checking, nothing outside.
	local frames: { number } = {}

	for _, entry in hitboxes do
		table.insert(frames, entry.frame)
	end

	table.sort(frames)

	equal("hitbox on frames 25-30", table.concat(frames, ","), "25,26,27,28,29,30")
	equal("targets in range", hitboxes[1] and hitboxes[1].targets or -1, 2)

	-- The swing effect is spawned a frame before the first check. Shifted by a
	-- frame, the effect would show up before the foot actually lands.
	local effects = world.trace:effects()
	local swingAt24 = false

	for _, entry in effects do
		if entry.frame == 24 and entry.name == "EmitFolder" and entry.action == "start" then
			swingAt24 = true
		end
	end

	check("swing effect starts at frame 24", swingAt24)
end

-- HITS ----------------------------------------------------------------------

do
	local world = scenario(2, 50)
	local attacks = world.trace:attacks()

	equal("attacks in total", #attacks, 2)

	for _, target in world.targets do
		local hits = world.trace:against(target)

		equal(`{target.instance.Name} is hit once`, #hits, 1)

		if hits[1] then
			equal(`damage on {target.instance.Name}`, hits[1].damage, 15)
			equal(`stun on {target.instance.Name}`, hits[1].stun.Duration, 1.5)
			equal("stun priority", hits[1].stun.Priority, 30)
		end
	end

	equal("first hit on frame 25", attacks[1] and attacks[1].frame or -1, 25)
end

-- EFFECTS ON VICTIMS --------------------------------------------------------

do
	local world = scenario(2, 50)
	local effects = world.trace:effects()

	local function started(frame: number, name: string): number
		local count = 0

		for _, entry in effects do
			if entry.frame == frame and entry.name == name and entry.action == "start" then
				count += 1
			end
		end

		return count
	end

	-- Unlike Uppercut, which plays the effect on the caster, this one plays an
	-- effect and an animation on every victim.
	equal("victim effects on the hit frame", started(25, "EmitFolder"), 2)
	equal("victim animations on the hit frame", started(25, "Animation"), 2)
end

-- PARAMETERS ----------------------------------------------------------------

do
	local world = scenario(1, 50)
	local params = world.trace:parameters()
	local names: { [string]: { [string]: number } } = {}

	for _, entry in params do
		names[entry.name] = names[entry.name] or {}
		names[entry.name][entry.action] = entry.frame
	end

	equal("MaxWalkSpeed set at frame 1", names.MaxWalkSpeed and names.MaxWalkSpeed.add or -1, 1)

	-- The sequence ends on frame 45, so that is when movement comes back.
	equal(
		"MaxWalkSpeed released at the end",
		names.MaxWalkSpeed and names.MaxWalkSpeed.remove or -1,
		45
	)
	equal(
		"MaxJumpPower released at the end",
		names.MaxJumpPower and names.MaxJumpPower.remove or -1,
		45
	)

	equal("walk speed after the hit", world.caster:GetParameter("MaxWalkSpeed"), 2048)
end

-- RESULT --------------------------------------------------------------------

print(`[tests.skills.Footrest] passed: {passed}, failed: {#failures}`)

if #failures > 0 then error(table.concat(failures, "\n"), 0) end
