--!strict
--- Test for the `Standless/Uppercut` skill.
---
---   lune run tests/skills/Uppercut.luau
---
--- The skill runs end to end: real source, real skin assets, real parameter
--- table. What is asserted is what usually only shows up in a playtest — which
--- frames check the hitbox, who gets hit, how many times, for how much damage,
--- when armor goes on and off, and that nothing is left behind afterwards.
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

--- `equal` takes an optional note: some checks fail not because of the value
--- but because a long list of frames did not match.
local function equal(name: string, actual: any, expected: any, detail: string?)
	local message = `expected {tostring(expected)}, got {tostring(actual)}`

	check(name, actual == expected, if detail then `{detail}: {message}` else message)
end

--- Run fixture: a world, an activated skill, its trace, and enough frames for
--- the sequence to finish.
local function scenario(targets: number, frames: number): any
	local world = Harness.world({ spec = "Standless", skin = "None", targets = targets })
	local skill = world:skill("Standless/Uppercut")

	skill:Activate()
	world:Step(frames)

	return world, skill
end

-- CONTRACT ------------------------------------------------------------------

do
	local world = Harness.world({ spec = "Standless", skin = "None" })
	local skill = world:skill("Standless/Uppercut")
	local data = skill.Data

	equal("DisplayName", data.DisplayName, "Uppercut")
	equal("Cooldown", data.Cooldown, 1)

	-- The tags promise behaviour that is verified for real further down, so the
	-- `Blockable` and `BlockBreaker` claims have to be backed by `AttackInfo`.
	check(
		"AttackInfo.Block.BlockBreak",
		data.AttackInfo.Block.BlockBreak == true,
		tostring(data.AttackInfo.Block.BlockBreak)
	)

	check(
		"AttackInfo.Block.PerfectBlockable",
		data.AttackInfo.Block.PerfectBlockable == true,
		tostring(data.AttackInfo.Block.PerfectBlockable)
	)

	equal("AttackInfo.Damage", data.AttackInfo.Damage, 15)
	equal("AttackInfo.Stun.Duration", data.AttackInfo.Stun.Duration, 0.7)
	equal("AttackInfo.Stun.Priority", data.AttackInfo.Stun.Priority, 20)
	equal("AttackInfo.Ragdoll.Duration", data.AttackInfo.Ragdoll.Duration, 2)
	equal("AttackInfo.Knockback.Speed", data.AttackInfo.Knockback.Speed, 30)

	for _, tag in data.SkillCharacters do
		check(`SkillCharacters contains {tag}`, true)
	end

	-- A skill must not require something the harness does not know: otherwise
	-- part of it would be verified against a stub without saying so.
	local unresolved = world:missingModules()
	equal("no unresolved modules", #unresolved, 0, table.concat(unresolved, ", "))
end

-- ASSETS --------------------------------------------------------------------

do
	local world = Harness.world({ spec = "Standless", skin = "None" })
	local skill = world:skill("Standless/Uppercut")

	skill:Activate()
	world:Step(40)

	-- Every key the skill takes from the skin has to exist. Asset names are
	-- strings: a typo passes the compiler and becomes `nil` mid-fight.
	local missing = world:missingAssets()
	equal("all skin assets resolve", #missing, 0, table.concat(missing, ", "))
end

-- TIMING --------------------------------------------------------------------

do
	local world = scenario(2, 40)
	local hitboxes = world.trace:hitboxes()

	-- The entry in the skill reads `{20, fn, 24}`: the hitbox is checked on
	-- every frame from 20 to 24 and nowhere else.
	local frames: { number } = {}

	for _, entry in hitboxes do
		table.insert(frames, entry.frame)
	end

	table.sort(frames)

	local expected = "20,21,22,23,24"
	local actual = table.concat(frames, ",")

	equal("hitbox on frames 20-24", actual, expected)
	equal("targets in range", hitboxes[1] and hitboxes[1].targets or -1, 2)
end

-- HITS ----------------------------------------------------------------------

do
	local world = scenario(2, 40)
	local attacks = world.trace:attacks()

	equal("attacks in total", #attacks, 2, `each of two targets must be hit exactly once`)

	-- Five hitbox checks and two hits: `AlreadyHit` stops a target from being
	-- struck again, otherwise five checks would produce ten attacks.
	for _, target in world.targets do
		local hits = world.trace:against(target)
		equal(`{target.instance.Name} is hit once`, #hits, 1)

		if hits[1] then
			equal(`damage on {target.instance.Name}`, hits[1].damage, 15)
			equal(`stun on {target.instance.Name}`, hits[1].stun.Duration, 0.7)
			equal("stun priority", hits[1].stun.Priority, 20)
			equal("ragdoll", hits[1].ragdoll.Duration, 2)
			equal("knockback speed", hits[1].knockback.Speed, 30)
			equal("breaks block", hits[1].block.BlockBreak, true)
		end
	end

	equal("first hit on frame 20", attacks[1] and attacks[1].frame or -1, 20)
end

-- ARMOR AND PARAMETERS ------------------------------------------------------

do
	local world = scenario(2, 40)
	local armor = world.trace:armor()

	equal("armor on", armor[1] and armor[1].enabled or false, true)
	equal("armor on at frame 1", armor[1] and armor[1].frame or -1, 1)
	equal("armor off", armor[2] and armor[2].removed or false, true)

	-- The skill removes armor on its own frame 30, not "at the end of the
	-- sequence": only the frame number tells the two apart.
	equal("armor off at frame 30", armor[2] and armor[2].frame or -1, 30)

	local params = world.trace:parameters()
	local names: { [string]: { [string]: number } } = {}

	for _, entry in params do
		names[entry.name] = names[entry.name] or {}
		names[entry.name][entry.action] = entry.frame
	end

	check("walk speed is limited", names.MaxWalkSpeed ~= nil)
	equal("MaxWalkSpeed set at frame 1", names.MaxWalkSpeed and names.MaxWalkSpeed.add or -1, 1)
	equal(
		"MaxWalkSpeed released at the end",
		names.MaxWalkSpeed and names.MaxWalkSpeed.remove or -1,
		35
	)

	check("jump is blocked", names.MaxJumpPower ~= nil)
	equal("MaxJumpPower set at frame 1", names.MaxJumpPower and names.MaxJumpPower.add or -1, 1)
	equal(
		"MaxJumpPower released at the end",
		names.MaxJumpPower and names.MaxJumpPower.remove or -1,
		35
	)

	-- After the sequence the character walks again: a parameter left behind
	-- would freeze the player after every uppercut.
	local character = world.caster

	equal("walk speed after the hit", character:GetParameter("MaxWalkSpeed"), 2048)
	equal("jump power after the hit", character:GetParameter("MaxJumpPower"), 4096)
	equal("armor after the hit", character:GetParameter("Armor"), false)
end

-- EFFECTS -------------------------------------------------------------------

do
	local world = scenario(2, 40)
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

	equal("animation at frame 1", started(1, "Animation"), 1)
	equal("swing effect at frame 1", started(1, "EmitFolder"), 1)
	equal("swing sound at frame 1", started(1, "Sound"), 1)

	-- On the hit frame there is one effect for the skill and one sound per
	-- victim, and there are two of them.
	equal("one hit effect", started(20, "EmitFolder"), 1)
	equal("one hit sound per target", started(20, "Sound"), 2)

	local stopped = 0

	for _, entry in effects do
		if entry.action == "stop" then
			stopped += 1
		end
	end

	equal("nothing is stopped during the hit", stopped, 0)
end

-- COOLDOWN ------------------------------------------------------------------

do
	local world = Harness.world({ spec = "Standless", skin = "None", targets = 1 })
	local skill = world:skill("Standless/Uppercut")

	check("skill is available before use", skill:Validate())

	skill:Activate()

	check("skill is on cooldown after use", skill:IsOnCooldown())
	check("skill fails validation while on cooldown", not skill:Validate())

	world:Step(60)
	check("cooldown expires after a second", not skill:IsOnCooldown())
	check("skill is available again after the cooldown", skill:Validate())
end

-- INTERRUPT -----------------------------------------------------------------

do
	local world = Harness.world({ spec = "Standless", skin = "None", targets = 1 })
	local skill = world:skill("Standless/Uppercut")

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

	equal("animation and sound stopped", #stopped, 2)
	equal("sequence stopped", skill.Sequence:IsPlaying(), false)
end

-- RESULT --------------------------------------------------------------------

print(`[tests.skills.Uppercut] passed: {passed}, failed: {#failures}`)

if #failures > 0 then error(table.concat(failures, "\n"), 0) end
