--!strict
--- Test for the `Standless/CircularKick` skill.
---
---   lune run tests/skills/CircularKick.luau
---
--- This one is a sphere hitbox rather than a box, it ignores block entirely, and
--- it carries its own i-frame priority so the kick lands on a ragdolled enemy.
--- All three are easy to break by editing a neighbouring skill.
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
	local skill = world:skill("Standless/CircularKick")

	skill:Activate()
	world:Step(frames)

	return world, skill
end

-- CONTRACT ------------------------------------------------------------------

do
	local world = Harness.world({ spec = "Standless", skin = "None" })
	local skill = world:skill("Standless/CircularKick")
	local data = skill.Data

	equal("DisplayName", data.DisplayName, "CircularKick")
	equal("Cooldown", data.Cooldown, 4)
	equal("AttackInfo.Damage", data.AttackInfo.Damage, 8)

	-- A number means a sphere radius; a Vector3 would mean a box. The two are
	-- not interchangeable and the difference is invisible in the code.
	equal("Hitbox is a sphere of radius 6", data.AttackInfo.Hitbox.Size, 6)

	-- The whole point of the kick: block is ignored, so a perfect block must
	-- not matter here.
	equal("Block is ignored", data.AttackInfo.Block.BlockIgnore, true)

	-- The skill raises its own i-frame priority so it reaches a ragdolled enemy:
	-- that value is `Enums.IFrames.Ragdoll`, which is 10. Grab is 50 and True is
	-- 10000, so a wrong constant here looks plausible and passes review.
	equal("i-frame priority", data.AttackInfo.Priority, 10)
	equal("Ragdoll.Duration", data.AttackInfo.Ragdoll.Duration, 0.5)
	equal("Knockback.Speed", data.AttackInfo.Knockback.Speed, 30)

	check("no stun: the kick is not meant to stagger", data.AttackInfo.Stun == nil)

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
	local world = scenario(2, 50)
	local attacks = world.trace:attacks()

	equal("attacks in total", #attacks, 2)

	for _, target in world.targets do
		local hits = world.trace:against(target)

		equal(`{target.instance.Name} is hit once`, #hits, 1)

		if hits[1] then
			equal(`damage on {target.instance.Name}`, hits[1].damage, 8)
			equal(`ragdoll on {target.instance.Name}`, hits[1].ragdoll.Duration, 0.5)
			equal(`knockback on {target.instance.Name}`, hits[1].knockback.Speed, 30)
		end
	end

	equal("first hit on frame 20", attacks[1] and attacks[1].frame or -1, 20)
end

-- EFFECTS -------------------------------------------------------------------

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

	-- The ground particle is spawned on frame 19, one frame before contact.
	equal("ground effect at frame 19", started(19, "EmitParticle"), 1)

	-- The hit sound is played once, on the first victim only: the source
	-- guards it with `#AlreadyHit <= 1`. Two targets, one sound.
	equal("hit sound played once", started(20, "Sound"), 1)
end

-- RESULT --------------------------------------------------------------------

print(`[tests.skills.CircularKick] passed: {passed}, failed: {#failures}`)

if #failures > 0 then error(table.concat(failures, "\n"), 0) end
