--!strict
--- Test for the `Standless/KnifeStab` skill.
---
---   lune run tests/skills/KnifeStab.luau
---
--- Three claims carry this skill and each is easy to break by editing a
--- neighbouring one: the hit ignores block, exactly one victim is stabbed no
--- matter how many targets the hitbox finds, and the bleed config travels on
--- the attack rather than being applied somewhere else.
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

--- Run fixture: a world, an activated skill and enough frames for the sequence
--- to finish.
local function scenario(targets: number, frames: number): any
	local world = Harness.world({ spec = "Standless", skin = "None", targets = targets })
	local skill = world:skill("Standless/KnifeStab")

	skill:Activate()
	world:Step(frames)

	return world, skill
end

-- CONTRACT ------------------------------------------------------------------

do
	local world = Harness.world({ spec = "Standless", skin = "None" })
	local skill = world:skill("Standless/KnifeStab")
	local data = skill.Data

	equal("DisplayName", data.DisplayName, "Knife Stab")
	equal("Cooldown", data.Cooldown, 5)
	equal("AttackInfo.Damage", data.AttackInfo.Damage, 10)

	-- A box, not a sphere radius: the two shapes are not interchangeable and
	-- the difference is invisible in the code. `Vector3` is not a Lune global,
	-- so the components are compared one by one.
	local size = data.AttackInfo.Hitbox.Size
	local offset = data.AttackInfo.Hitbox.Offset.Position

	check("Hitbox is a 6x6x6 box", size.X == 6 and size.Y == 6 and size.Z == 6, tostring(size))
	check(
		"Hitbox is in front of the caster",
		offset.X == 0 and offset.Y == 0 and offset.Z == -3,
		tostring(offset)
	)

	-- The one-victim rule is built on this: without distance sorting the
	-- hitbox hands targets over in an arbitrary order.
	equal("Hitbox sorts by distance", data.AttackInfo.Hitbox.SortByDistance, true)

	-- The whole point of the stab: block is ignored, so a perfect block must
	-- not matter here either.
	equal("Block is ignored", data.AttackInfo.Block.BlockIgnore, true)
	equal("perfect block does not apply", data.AttackInfo.Block.PerfectBlockable, false)

	equal("Bleed.Damage", data.AttackInfo.Bleed.Damage, 1)
	equal("Bleed.Duration", data.AttackInfo.Bleed.Duration, 3)
	equal("Bleed.Interval", data.AttackInfo.Bleed.Interval, 0.5)
	equal("Bleed.Slow", data.AttackInfo.Bleed.Slow, 8)

	check("no stun: the stab staggers nobody", data.AttackInfo.Stun == nil)

	local unresolved = world:missingModules()
	equal("no unresolved modules", #unresolved, 0, table.concat(unresolved, ", "))
end

-- ASSETS --------------------------------------------------------------------

do
	local world = scenario(1, 35)

	local missing = world:missingAssets()
	equal("all skin assets resolve", #missing, 0, table.concat(missing, ", "))
end

-- TIMING --------------------------------------------------------------------

do
	local world = scenario(2, 35)
	local hitboxes = world.trace:hitboxes()

	-- `{20, fn, 25}` in the source.
	local frames: { number } = {}

	for _, entry in hitboxes do
		table.insert(frames, entry.frame)
	end

	table.sort(frames)

	equal("hitbox on frames 20-25", table.concat(frames, ","), "20,21,22,23,24,25")
	equal("targets in range", hitboxes[1] and hitboxes[1].targets or -1, 2)
end

-- HITS ----------------------------------------------------------------------

do
	local world = scenario(2, 35)
	local attacks = world.trace:attacks()

	-- Six hitbox checks and one attack: the skill takes its victim before the
	-- attack resolves, so the remaining checks have nobody left to stab.
	equal("attacks in total", #attacks, 1, "one cast must stab exactly one target")

	local first = world.trace:against(world.targets[1])
	local second = world.trace:against(world.targets[2])

	equal("closest target is hit once", #first, 1)
	equal("farther target is left alone", #second, 0)

	if first[1] then
		equal("damage", first[1].damage, 10)

		-- The debuff travels on the attack: the bleed hook reads it from there,
		-- so a config that never reaches `Info` is a debuff nobody ever gets.
		check("attack carries the bleed config", first[1].bleed ~= nil)
		equal("bleed damage per tick", first[1].bleed and first[1].bleed.Damage, 1)
		equal("bleed duration", first[1].bleed and first[1].bleed.Duration, 3)
		equal("bleed slowdown", first[1].bleed and first[1].bleed.Slow, 8)
	end

	equal("first hit on frame 20", attacks[1] and attacks[1].frame or -1, 20)
end

-- EQUIP ---------------------------------------------------------------------

do
	local world = scenario(1, 35)
	local equips = 0

	for _, entry in world.trace.entries do
		if entry.data.kind == "equip" then
			equips += 1
			equal("knife is mounted on the first frame", entry.data.frame, 0)
		end
	end

	equal("knife equipped once", equips, 1)
end

-- EFFECTS -------------------------------------------------------------------

do
	local world = scenario(2, 35)
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

	equal("animation at frame 0", started(0, "Animation"), 1)
	equal("swing sound at frame 0", started(0, "Sound"), 1)

	-- One victim, one hit sound, one impact effect - no matter that the hitbox
	-- was checked six times.
	equal("hit sound on the victim", started(20, "Sound"), 1)
	equal("impact effect on the victim", started(20, "EmitParticle"), 1)

	local stopped = 0

	for _, entry in effects do
		if entry.action == "stop" then
			stopped += 1
		end
	end

	equal("nothing is stopped during the run", stopped, 0)
end

-- CLEANUP -------------------------------------------------------------------

do
	local world = scenario(2, 35)
	local params = world.trace:parameters()
	local names: { [string]: { [string]: number } } = {}

	for _, entry in params do
		names[entry.name] = names[entry.name] or {}
		names[entry.name][entry.action] = entry.frame
	end

	check("walk speed is limited", names.MaxWalkSpeed ~= nil)
	equal("MaxWalkSpeed set at frame 0", names.MaxWalkSpeed and names.MaxWalkSpeed.add or -1, 0)
	equal(
		"MaxWalkSpeed released at the end",
		names.MaxWalkSpeed and names.MaxWalkSpeed.remove or -1,
		30
	)

	check("jump is blocked", names.MaxJumpPower ~= nil)
	equal("MaxJumpPower set at frame 0", names.MaxJumpPower and names.MaxJumpPower.add or -1, 0)
	equal(
		"MaxJumpPower released at the end",
		names.MaxJumpPower and names.MaxJumpPower.remove or -1,
		30
	)

	-- A parameter left behind would freeze the player after every stab.
	local character = world.caster

	equal("walk speed after the stab", character:GetParameter("MaxWalkSpeed"), 2048)
	equal("jump power after the stab", character:GetParameter("MaxJumpPower"), 4096)
end

-- COOLDOWN ------------------------------------------------------------------

do
	local world = Harness.world({ spec = "Standless", skin = "None", targets = 1 })
	local skill = world:skill("Standless/KnifeStab")

	check("skill is available before use", skill:Validate())

	skill:Activate()

	check("skill is on cooldown after use", skill:IsOnCooldown())
	check("skill fails validation while on cooldown", not skill:Validate())

	world:Step(60)
	check("still on cooldown after a second", skill:IsOnCooldown())

	-- 60 frames of `Step` are `1/60` each, and 300 of them land a hair under
	-- five seconds; the extra frame keeps the check about the cooldown and not
	-- about floating point.
	world:Step(301)
	check("cooldown expires after five seconds", not skill:IsOnCooldown())
	check("skill is available again after the cooldown", skill:Validate())
end

-- INTERRUPT -----------------------------------------------------------------

do
	local world = Harness.world({ spec = "Standless", skin = "None", targets = 1 })
	local skill = world:skill("Standless/KnifeStab")

	skill:Activate()
	world:Step(5)

	-- An interrupt arrives from outside mid-activation. Activation ends
	-- synchronously here, so the flag is raised by hand: what is under test is
	-- the cleanup code of the skill, not the order of calls.
	skill.Active = true
	skill:Interrupt()

	local stopped: { string } = {}

	for _, entry in world.trace:effects() do
		if entry.action == "stop" then table.insert(stopped, entry.name) end
	end

	equal("animation stopped", #stopped, 1)
	equal("the stop is the animation", stopped[1], "Animation")
	equal("sequence stopped", skill.Sequence:IsPlaying(), false)
end

-- RESULT --------------------------------------------------------------------

print(`[tests.skills.KnifeStab] passed: {passed}, failed: {#failures}`)

if #failures > 0 then error(table.concat(failures, "\n"), 0) end
