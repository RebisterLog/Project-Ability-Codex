--!strict
--- Tests for `BotService`: the priority scorer, the defense rules and bot configs.
---
---   lune run tools/tests/bot-skill-priority.luau
---
--- Neither the scorer nor the defense talks to Roblox, but both pull in
--- `ReplicatedStorage` for the config types, and `lune` does not let one script
--- patch the globals of another. So the real module source is taken and only the
--- lines that cannot run outside Studio are replaced. The logic itself is tested
--- as is, without a copy.
---
--- `require` inside a chunk loaded through `loadstring` does not work in `lune`,
--- so dependencies are inlined into the text as source (see `inline`).

local botCharacters = require("../../src/shared/bot-characters")
local fs = require("@lune/fs")

local BOT_PATH = "src/server/services/BotService/"

local CONDITIONS_PATH = BOT_PATH .. "Conditions.luau"
local PRIORITY_PATH = BOT_PATH .. "SkillPriority.luau"
local DEFENSE_PATH = BOT_PATH .. "Defense.luau"

--- Replacements for the parts that cannot run outside Roblox. The way a module
--- reaches the service differs, so none of them is required to match: the real
--- check is done by `loadModule`, no `GetService` may survive the substitutions.
--- `bot-characters` is only needed by modules for its types, so it becomes an empty
--- table: the vocabulary is verified separately, through a real `require`.
local REQUIRES: { { pattern: string, replacement: string } } = {
	{
		pattern = [[require%(ReplicatedStorage%.shared%["bot%-characters"%]%)]],
		replacement = "{}",
	},
	{
		pattern = [[require%(game:GetService%("ReplicatedStorage"%)%.shared%["bot%-characters"%]%)]],
		replacement = "{}",
	},
}

--- Getting a service can be neutralized where it is used and stays harmless where
--- it is not (self-contained modules like `BotService/Conditions`).
local SERVICE_OPTIONAL: { { pattern: string, replacement: string } } = {
	{
		pattern = [[local ReplicatedStorage = game:GetService%("ReplicatedStorage"%)]],
		replacement = "local ReplicatedStorage = nil",
	},
}

local function applyStubs(
	source: string,
	stubs: { { pattern: string, replacement: string } },
	required: boolean?
): string
	for _, stub in stubs do
		-- A function replacement inserts the string verbatim, so a `%` inside it is
		-- not read as a group reference.
		local result = string.gsub(source, stub.pattern, function()
			return stub.replacement
		end)
		if required ~= false then assert(result ~= source, `stub did not match: {stub.pattern}`) end

		source = result
	end

	return source
end

local function compile(source: string, path: string): any
	local chunk = loadstring(source, `={path}`)
	assert(chunk ~= nil, `failed to compile {path}`)

	local module = chunk()
	assert(type(module) == "table", `{path} did not return a table`)

	return module
end

--- Wraps a source in an IIFE so it can be inlined into another module.
local function inline(source: string): string
	return `(function()\n{source}\nend)()`
end

--- Reads a module, replaces the Roblox lines and returns the ready source.
---
--- `roblox = false` is for self-contained modules that do not reach for Studio at
--- all, where there is nothing to replace.
local function readSource(
	path: string,
	stubs: { { pattern: string, replacement: string } }?,
	roblox: boolean?
): string
	local source = fs.readFile(path)

	if roblox ~= false then
		source = applyStubs(source, REQUIRES, false)
		source = applyStubs(source, SERVICE_OPTIONAL, false)

		assert(
			string.find(source, "GetService", 1, true) == nil,
			`{path} still reaches for Roblox after stubbing`
		)
	end

	if stubs then source = applyStubs(source, stubs) end

	return source
end

--- Loads a config or a bot module. Types from `bot-characters` are only needed by
--- the analyzer, the table is empty at runtime.
local function loadModule(
	path: string,
	stubs: { { pattern: string, replacement: string } }?,
	roblox: boolean?
): any
	return compile(readSource(path, stubs, roblox), path)
end

--- `Conditions` holds only bits and knows nothing about Roblox, which is exactly
--- why the very same file loads here and in Studio.
local Conditions = loadModule(CONDITIONS_PATH, nil, false)

--- The scorer source is needed twice: as a module and as a dependency of the
--- defense. So it is prepared once — the raw file would carry `game:GetService`
--- into the runtime.
local prioritySource = readSource(PRIORITY_PATH, {
	{
		pattern = [[require%(script%.Parent%.Conditions%)]],
		replacement = inline(fs.readFile(CONDITIONS_PATH)),
	},
})

local SkillPriority = compile(prioritySource, PRIORITY_PATH)

local Defense = loadModule(DEFENSE_PATH, {
	{
		pattern = [[require%(script%.Parent%.Conditions%)]],
		replacement = inline(fs.readFile(CONDITIONS_PATH)),
	},
	{
		pattern = [[require%(script%.Parent%.SkillPriority%)]],
		replacement = inline(prioritySource),
	},
})

--- Conditions are written as lists of strings in the tests, exactly like in the
--- configs; the scorer and the defense receive a mask.
local function mask(list: { any }): number
	return Conditions.Mask(list)
end

local CONFIG_FILES = {
	"src/shared/configs/Bots/Undyne.luau",
	"src/shared/configs/Bots/Gerson.luau",
	"src/shared/configs/Bots/Dio.luau",
	"src/shared/configs/Bots/BasicWarrior.luau",
}

local passed = 0
local failures: { string } = {}

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		return
	end

	table.insert(failures, if detail ~= nil then `{name}: {detail}` else name)
end

local function equal(name: string, actual: any, expected: any)
	check(name, actual == expected, `expected {tostring(expected)}, got {tostring(actual)}`)
end

local function candidate(id: string): any
	return { Data = { Id = id } }
end

--- Candidate list. Takes an array and not `...`: `...` cannot be iterated when
--- called with a single argument, because then it is the string itself.
local function candidates(ids: { string }): { any }
	local list = {}
	for _, id in ids do
		table.insert(list, candidate(id))
	end
	return list
end

--- Minimal config: unit weights, empty combo.
local function makeConfig(skills: any, weights: any?): any
	return {
		Spec = "Test",
		Chaotic = 0,
		Aggressive = 0.5,
		Reaction = 0.5,
		Agility = 0.5,
		ConditionWeight = (weights and weights.ConditionWeight) or 1,
		ComboWeight = (weights and weights.ComboWeight) or 1,
		Skills = skills,
		Combos = {},
	}
end

--- A skill set that mirrors a bot layout: a close attack, a guard, a ranged
--- attack, a grab with a required condition and an escape.
local SKILLS = {
	Punch = {
		Priority = 0,
		Distance = 8,
		PreferredDistance = { Min = 5, Max = 8 },
		PreferredConditions = { "TARGET_SHORT_RANGE" },
		PenaltyConditions = { "TARGET_ATTACKING" },
	},
	Block = {
		PreferredConditions = { "TARGET_BLOCKABLE", "TARGET_PERFECT_BLOCKABLE" },
		ForbiddenConditions = { "TARGET_IGNORE_BLOCK" },
	},
	Barrage = {
		Distance = 10,
		PreferredConditions = { "TARGET_RAGDOLLED" },
	},
	Grab = {
		RequiredConditions = { "TARGET_BLOCKING" },
	},
	Dash = {
		PreferredConditions = { "TARGET_ATTACKING", "TARGET_IGNORE_BLOCK" },
	},
}

local ALL = candidates({ "Punch", "Block", "Barrage", "Grab", "Dash" })

local function selectBest(
	conditions: { any },
	distance: number,
	combo: string?,
	skills: any?,
	weights: any?
)
	return SkillPriority.Select(
		makeConfig(skills or SKILLS, weights),
		ALL,
		mask(conditions),
		distance,
		combo
	)
end

-- MODULE PATHS ------------------------------------------------------------

--- In Roblox `script.X` is a CHILD of the module, not a sibling in the folder.
--- Modules inside `BotService` have no children (Rojo creates no sub-folders), so
--- any `require(script.X)` there is a wrong path and `script.Parent.X` is needed.
---
--- Studio reports this as "X is not a valid member" and it can only be caught by
--- running, so the check is static and lives here.
local MODULE_FILES = {
	"src/server/services/BotService/Bot.luau",
	"src/server/services/BotService/SkillPriority.luau",
	"src/server/services/BotService/Conditions.luau",
	"src/server/services/BotService/Defense.luau",
	"src/server/services/BotService/Sense.luau",
	"src/server/services/BotService/Threat.luau",
	"src/server/services/BotService/Posture.luau",
	"src/server/services/BotService/Attack.luau",
}

for _, path in MODULE_FILES do
	local name = string.match(path, "([^/]+)%.luau$") :: string
	local source = fs.readFile(path)

	for dependency in string.gmatch(source, "require%((script[^%)]+)%)") do
		check(
			`{name}: siblings are reached through script.Parent`,
			string.find(dependency, "^script%.Parent%.") ~= nil,
			`require({dependency}) looks for a child of the module`
		)
	end

	--- `function X:Method(self: X)` declares a METHOD with two parameters: the
	--- implicit one and the explicit `self`. A call `instance:Method()` passes
	--- `nil` as the second one, and the failure lands inside the method, on the
	--- most innocent `self.Target`. An explicit `self` therefore only goes with a
	--- dot.
	for declaration in string.gmatch(source, "function%s+[%w_]+:[%w_]+%(%s*self") do
		check(
			`{name}: an explicit self needs dot syntax`,
			false,
			`{declaration} declares a second, always nil parameter`
		)
	end
end

-- CONDITION VOCABULARY ----------------------------------------------------

do
	-- Diverging vocabularies break masks silently: an unknown condition becomes
	-- zero bits and the rule in the config simply stops working.
	local unknown = 0
	for _, name in Conditions.Names do
		if botCharacters.SkillConditions[name] == nil then
			unknown += 1
		end
	end
	equal("vocabulary: no conditions outside the dictionary", unknown, 0)

	local missing = 0
	for name in botCharacters.SkillConditions do
		if Conditions.Bit(name) == 0 then
			missing += 1
		end
	end
	equal("vocabulary: no conditions missing from the mask module", missing, 0)

	local incoming = mask({ "TARGET_BLOCKABLE", "TARGET_PERFECT_BLOCKABLE" })
	check("mask: unrelated condition is absent", not Conditions.Has(incoming, "TARGET_STUNNED"))
	check(
		"mask: HasAny sees a single match",
		Conditions.HasAny(incoming, { "TARGET_STUNNED", "TARGET_BLOCKABLE" })
	)
	check("mask: HasAny on an empty list", not Conditions.HasAny(incoming, {}))
	equal(
		"mask: Count sums matches",
		Conditions.Count(
			incoming,
			{ "TARGET_STUNNED", "TARGET_BLOCKABLE", "TARGET_PERFECT_BLOCKABLE" }
		),
		2
	)
	equal("mask: unknown condition contributes no bits", Conditions.Mask({ "TARGET_NONSENSE" }), 0)
	equal("mask: empty mask has no conditions", Conditions.Has(0, "TARGET_BLOCKABLE"), false)
end

-- EMPTY CASES --------------------------------------------------------------

do
	equal("empty candidates: nil", SkillPriority.Select(makeConfig(SKILLS), {}, 0, 6, nil), nil)
	equal(
		"skill missing from config is skipped",
		SkillPriority.Select(makeConfig(SKILLS), candidates({ "Run" }), 0, 6, nil),
		nil
	)
end

-- HARD FILTERS -------------------------------------------------------------

do
	local config = makeConfig({ Grab = { RequiredConditions = { "TARGET_BLOCKING" } } })
	equal(
		"required: missing condition excludes the skill",
		SkillPriority.Select(config, candidates({ "Grab" }), 0, 6, nil),
		nil
	)

	local met =
		SkillPriority.Select(config, candidates({ "Grab" }), mask({ "TARGET_BLOCKING" }), 6, nil)
	equal("required: met condition keeps the skill", met and met.Id, "Grab")
end

do
	local config = makeConfig({
		Block = { ForbiddenConditions = { "TARGET_IGNORE_BLOCK" } },
	})
	equal(
		"forbidden: present condition excludes the skill",
		SkillPriority.Select(
			config,
			candidates({ "Block" }),
			mask({ "TARGET_IGNORE_BLOCK" }),
			6,
			nil
		),
		nil
	)
end

do
	local config = makeConfig({ Punch = { Distance = 8 } })
	equal(
		"distance: beyond max excludes the skill",
		SkillPriority.Select(config, candidates({ "Punch" }), 0, 8.5, nil),
		nil
	)

	local inside = SkillPriority.Select(config, candidates({ "Punch" }), 0, 8, nil)
	equal("distance: exactly at max is still allowed", inside and inside.Id, "Punch")
end

-- SOFT CONDITIONS ----------------------------------------------------------

do
	-- The target attacks up close: Punch = +1 (distance) -1 (attacking) +1 (close)
	-- = 1, Dash = +1 (attacking) = 1, Block/Grab are out of the running, Barrage = 0.
	local result = selectBest({ "TARGET_SHORT_RANGE", "TARGET_ATTACKING" }, 6)
	equal("preferred and penalty net out", result and result.Score, 1)
	check(
		"tie is resolved to one of the tied skills",
		result ~= nil and (result.Id == "Punch" or result.Id == "Dash"),
		result and result.Id
	)
end

do
	-- A penalty does not forbid: the only candidate comes back with a negative score.
	local config = makeConfig({ Punch = { PenaltyConditions = { "TARGET_ATTACKING" } } })
	local result =
		SkillPriority.Select(config, candidates({ "Punch" }), mask({ "TARGET_ATTACKING" }), 6, nil)

	equal("penalty: skill is still selectable", result and result.Id, "Punch")
	equal("penalty: score goes below zero", result and result.Score, -1)
end

do
	-- Minus one, but the distance band covers the penalty.
	local config = makeConfig({
		Punch = {
			Distance = 8,
			PreferredDistance = { Min = 5, Max = 8 },
			PenaltyConditions = { "TARGET_ATTACKING" },
		},
	})

	local inside =
		SkillPriority.Select(config, candidates({ "Punch" }), mask({ "TARGET_ATTACKING" }), 6, nil)
	equal("preferred distance adds to the penalty", inside and inside.Score, 0)

	local outside =
		SkillPriority.Select(config, candidates({ "Punch" }), mask({ "TARGET_ATTACKING" }), 4, nil)
	equal("outside the band the bonus is absent", outside and outside.Score, -1)
end

do
	local config = makeConfig({
		Block = { PreferredConditions = { "TARGET_BLOCKABLE", "TARGET_PERFECT_BLOCKABLE" } },
	})

	local one =
		SkillPriority.Select(config, candidates({ "Block" }), mask({ "TARGET_BLOCKABLE" }), 6, nil)
	equal("preferred: one matched condition", one and one.Score, 1)

	local two = SkillPriority.Select(
		config,
		candidates({ "Block" }),
		mask({ "TARGET_BLOCKABLE", "TARGET_PERFECT_BLOCKABLE" }),
		6,
		nil
	)
	equal("preferred: matched conditions add up", two and two.Score, 2)
end

do
	local config = makeConfig({
		Punch = {
			Distance = 8,
			PreferredDistance = { Min = 5, Max = 8 },
			PreferredConditions = { "TARGET_SHORT_RANGE" },
		},
	}, { ConditionWeight = 2 })

	local result = SkillPriority.Select(
		config,
		candidates({ "Punch" }),
		mask({ "TARGET_SHORT_RANGE" }),
		6,
		nil
	)
	equal("weight: every soft source is multiplied", result and result.Score, 4)
end

do
	-- A band with a single bound: Min without Max and Max without Min.
	local config = makeConfig({ Punch = { PreferredDistance = { Min = 12 } } })
	local far = SkillPriority.Select(config, candidates({ "Punch" }), 0, 20, nil)
	equal("preferred distance: open upper bound", far and far.Score, 1)

	local config2 = makeConfig({ Punch = { PreferredDistance = { Max = 6 } } })
	local near = SkillPriority.Select(config2, candidates({ "Punch" }), 0, 6, nil)
	equal("preferred distance: open lower bound", near and near.Score, 1)

	local beyond = SkillPriority.Select(config2, candidates({ "Punch" }), 0, 7, nil)
	equal("preferred distance: outside gives nothing", beyond and beyond.Score, 0)
end

-- COMBO ---------------------------------------------------------------------

do
	-- Exactly at the threshold: without a combo the close attack wins, with one the plan wins.
	local open = selectBest({}, 6)
	equal("combo: plan only biases an exact tie", open and open.Id, "Punch")

	local planned = selectBest({}, 6, "Barrage")
	equal("combo: wins the tie against conditions", planned and planned.Id, "Barrage")
	equal("combo: bonus raises the planned skill", planned and planned.Score, 1)
end

do
	-- Two matched conditions outweigh the plan bonus: Block = 2, Punch = 1 (combo),
	-- Barrage = 1 (ragdoll), and the distance of 4 is outside the Punch band.
	local result = selectBest({
		"TARGET_BLOCKABLE",
		"TARGET_PERFECT_BLOCKABLE",
		"TARGET_RAGDOLLED",
	}, 4, "Punch")

	equal("combo: matched conditions outweigh the plan bonus", result and result.Id, "Block")
	equal("combo: winner keeps its own score", result and result.Score, 2)
end

do
	local config = makeConfig({ Punch = {}, Barrage = {} }, { ComboWeight = 5 })
	local result = SkillPriority.Select(config, candidates({ "Punch", "Barrage" }), 0, 6, "Barrage")

	equal("combo weight is configurable", result and result.Score, 5)
end

do
	-- A skill from the combo drops out on a hard filter, and the bonus does not save
	-- it: Grab requires `TARGET_BLOCKING`, no condition is met, and the plan points
	-- at Grab.
	local result = selectBest({}, 6, "Grab")

	equal("combo: ineligible planned skill is skipped", result and result.Id, "Punch")
end

-- HOLDING --------------------------------------------------------------------

do
	local config = makeConfig({
		Block = {
			HoldWhile = { "TARGET_BLOCKABLE", "TARGET_PERFECT_BLOCKABLE" },
			HoldUntil = { "TARGET_STUNNED" },
		},
	})

	-- The target winds up a blockable attack: keep holding, even though the guard loses
	-- on priority to everything else.
	local held = SkillPriority.ShouldRelease(
		config,
		"Block",
		mask({ "TARGET_ATTACKING", "TARGET_BLOCKABLE" }),
		"Punch"
	)
	equal("hold while: keeps the block during a blockable attack", held, false)

	-- The threat is gone, so the guard has to release, even if the best candidate
	-- happens to be a skill on cooldown.
	local idle = SkillPriority.ShouldRelease(config, "Block", 0, nil)
	equal("hold while: releases when the attack is over", idle, true)

	-- The emergency abort is stronger than holding.
	local stunned = SkillPriority.ShouldRelease(
		config,
		"Block",
		mask({ "TARGET_BLOCKABLE", "TARGET_STUNNED" }),
		"Punch"
	)
	equal("hold until: emergency abort beats hold while", stunned, true)
end

do
	-- `HoldWhile` is set, but not a single condition is met.
	local config = makeConfig({ Block = { HoldWhile = { "TARGET_BLOCKABLE" } } })
	equal(
		"hold while: a single unsatisfied condition releases",
		SkillPriority.ShouldRelease(config, "Block", mask({ "TARGET_ATTACKING" }), "Punch"),
		true
	)
end

do
	-- Fallback by recomputation: `HoldWhile` is not set, so hold while the skill wins.
	local config = makeConfig({ Block = {} })

	equal(
		"hold fallback: stays while it is the best candidate",
		SkillPriority.ShouldRelease(config, "Block", 0, "Block"),
		false
	)

	equal(
		"hold fallback: releases once another skill wins",
		SkillPriority.ShouldRelease(config, "Block", 0, "Punch"),
		true
	)

	-- With every alternative on cooldown there is still a reason to hold.
	equal(
		"hold fallback: no alternatives means keep holding",
		SkillPriority.ShouldRelease(config, "Block", 0, nil),
		false
	)
end

do
	-- A skill without any settings in the config is not worth holding.
	equal(
		"hold: unknown skill releases immediately",
		SkillPriority.ShouldRelease(makeConfig(SKILLS), "Nope", 0, "Punch"),
		true
	)
end

-- GUARD AGAINST AN IDLE TARGET ------------------------------------------------

do
	-- Regression: a guard with no `HoldWhile` and no reason to stay held forever and
	-- silenced every other skill. With `HoldWhile` it releases as soon as the target
	-- goes quiet.
	local config = makeConfig({
		Block = { HoldWhile = { "TARGET_BLOCKABLE" } },
		Punch = { Priority = 1 },
	})

	local conditions = mask({ "TARGET_SHORT_RANGE" })
	local rival = SkillPriority.Select(config, candidates({ "Punch" }), conditions, 6, nil)
	local released = SkillPriority.ShouldRelease(config, "Block", conditions, rival and rival.Id)

	equal("idle: block is dropped as soon as nothing threatens", released, true)
	equal("idle: punch takes the slot", rival and rival.Id, "Punch")
end

do
	-- An empty list is truthy in Luau: without the check, `HoldWhile = {}` would mean
	-- "release every frame" instead of "holding is not configured".
	local config = makeConfig({ Block = { HoldWhile = {} } })
	equal(
		"hold while: empty list falls back to recompute",
		SkillPriority.ShouldRelease(config, "Block", 0, "Block"),
		false
	)

	local gone = SkillPriority.ShouldRelease(config, "Block", 0, "Punch")
	equal("hold while: empty list still loses to a better skill", gone, true)
end

-- DEFENSE ROLES ----------------------------------------------------------------

local function roleSkill(id: string, tags: { string }?): any
	return { Id = id, Tags = tags }
end

do
	local roles = Defense.ResolveRoles({
		roleSkill("Punch", { "Hit", "Stun" }),
		roleSkill("Block", { "Defense" }),
		roleSkill("Dash", { "Escape", "Defense", "ComboStarter" }),
		roleSkill("Counter", { "Counter", "Defense", "ComboStarter" }),
		roleSkill("Summon", nil),
	})

	equal("roles: guard comes from the Defense tag", roles.Guard, "Block")
	equal("roles: escape needs Defense and Escape", roles.Escape, "Dash")
	check("roles: counter is an attack, not a guard", roles.Guard ~= "Counter")
	equal("roles: a skill without tags is not a guard", roles.Guard, "Block")

	local bare = Defense.ResolveRoles({ roleSkill("Punch", { "Hit" }) })
	equal("roles: no defense tags means no guard", bare.Guard, nil)
	equal("roles: no defense tags means no escape", bare.Escape, nil)
end

-- REACTION TO A HIT --------------------------------------------------------------

local function incoming(tags: { string }?): any
	return { Skill = { Data = { SkillCharacters = tags } } }
end

--- Positional arguments instead of a table: "there is no guard" cannot be
--- expressed with overrides, because `{ GuardId = nil }` is an empty table in Luau.
local function context(guardId: string?, escapeId: string?, held: boolean, cooldown: boolean): any
	return {
		GuardId = guardId,
		EscapeId = escapeId,
		GuardHeld = held,
		GuardOnCooldown = cooldown,
	}
end

do
	local READY = context("Block", "Dash", false, false)

	equal(
		"react: blockable attack presses the guard",
		Defense.React(incoming({ "Blockable" }), READY),
		"Press"
	)

	equal(
		"react: perfect-blockable attack presses the guard",
		Defense.React(incoming({ "PerfectBlockable" }), READY),
		"Press"
	)

	-- A skill may be written with the value of the tag instead of the vocabulary key.
	equal(
		"react: 'PerfectBlock' spelling is the same condition",
		Defense.React(incoming({ "PerfectBlock" }), READY),
		"Press"
	)

	-- An active Block does not restart, so a "fresh press" on an already held guard
	-- would not refresh the perfect-block window. The tick has to free it, before
	-- the hit even arrives.
	equal(
		"react: a held guard stays held instead of pretending to re-press",
		Defense.React(incoming({ "PerfectBlockable" }), context("Block", "Dash", true, false)),
		"Hold"
	)

	equal(
		"react: guard on cooldown falls back to the escape",
		Defense.React(incoming({ "Blockable" }), context("Block", "Dash", false, true)),
		"Escape"
	)

	equal(
		"react: unblockable hit evades instead of blocking",
		Defense.React(incoming({ "Hit" }), READY),
		"Escape"
	)

	equal("react: no threat tags", Defense.React(incoming(nil), READY), "Escape")

	equal(
		"react: a spec without a guard evades instead",
		Defense.React(incoming({ "Blockable" }), context(nil, "Dash", false, false)),
		"Escape"
	)

	equal(
		"react: a spec without any defense skill does nothing",
		Defense.React(incoming({ "Blockable" }), context(nil, nil, false, false)),
		"Ignore"
	)
end

-- RELEASING THE GUARD ----------------------------------------------------------------

do
	local config = makeConfig({
		Block = { HoldWhile = { "TARGET_BLOCKABLE", "TARGET_PERFECT_BLOCKABLE" } },
	})

	equal(
		"guard: a blockable threat keeps it up",
		Defense.ShouldReleaseGuard(config, "Block", mask({ "TARGET_BLOCKABLE" })),
		false
	)

	equal(
		"guard: silence releases it",
		Defense.ShouldReleaseGuard(config, "Block", mask({ "TARGET_ATTACKING" })),
		true
	)

	-- Perfect-block regression: a held guard does not refresh the window, so on a
	-- parryable attack it has to be freed ahead of time, whatever `HoldWhile` says.
	equal(
		"guard: a perfect-blockable threat overrides the hold rule",
		Defense.ShouldReleaseGuard(config, "Block", mask({ "TARGET_PERFECT_BLOCKABLE" })),
		true
	)

	equal(
		"guard: unknown guard releases immediately",
		Defense.ShouldReleaseGuard(config, "Nope", mask({ "TARGET_BLOCKABLE" })),
		true
	)
end

-- SHOULD THE BOT BACK OFF --------------------------------------------------------

do
	-- The guard goes up for what a block can take. Without this rule the counter
	-- attack (`RequiredConditions = TARGET_ATTACKING`) could never fire: the very
	-- windup it waits for sent the bot into the defense, where there is no attack
	-- layer at all.
	equal(
		"defend: a blockable windup holds the guard",
		Defense.ShouldDefend(mask({ "TARGET_ATTACKING", "TARGET_BLOCKABLE" }), false),
		true
	)

	equal(
		"defend: a perfect-blockable windup holds the guard",
		Defense.ShouldDefend(mask({ "TARGET_ATTACKING", "TARGET_PERFECT_BLOCKABLE" }), false),
		true
	)

	-- `Grab` and `CircularKick`: there is a windup, but a block does not take it,
	-- so this is a window for a counter attack rather than for a retreat.
	equal(
		"defend: an unblockable windup leaves the slot free",
		Defense.ShouldDefend(mask({ "TARGET_ATTACKING", "TARGET_IGNORE_BLOCK" }), false),
		false
	)

	equal(
		"defend: a silent target is not a threat",
		Defense.ShouldDefend(mask({ "TARGET_SHORT_RANGE" }), false),
		false
	)

	-- The hit already landed: the impact window has passed and backing off is all
	-- that is left.
	equal(
		"defend: a landed hit outranks the conditions",
		Defense.ShouldDefend(mask({ "TARGET_SHORT_RANGE" }), true),
		true
	)
end

-- BOT CONFIGS ---------------------------------------------------------------------

local CONDITION_GROUPS = {
	"RequiredConditions",
	"ForbiddenConditions",
	"PreferredConditions",
	"PenaltyConditions",
	"HoldUntil",
	"HoldWhile",
}

for _, path in CONFIG_FILES do
	local name = string.match(path, "([^/]+)%.luau$") :: string
	local config = loadModule(path)

	for skillId, options in config.Skills do
		for _, group in CONDITION_GROUPS do
			for _, condition in (options[group] or {}) do
				check(
					`{name}/{skillId}: unknown condition in {group}`,
					botCharacters.SkillConditions[condition] ~= nil,
					tostring(condition)
				)
			end
		end
	end

	--- A skill that is missing from `Skills` is cut by the allowlist and will never
	--- fire, not even if it stands in a combo.
	for _, combo in config.Combos do
		check(`{name}: combo is not empty`, #combo > 0)

		for _, skillId in combo do
			check(
				`{name}: combo skill is described in Skills`,
				config.Skills[skillId] ~= nil,
				`{skillId} is used in a combo but has no options`
			)
		end
	end

	--- A combo without skills is meaningless: the plan gives a bonus to nobody.
	check(`{name}: has at least one combo`, #(config.Combos or {}) > 0)

	--- Perfect block needs a fresh press of Block in the frame of the impact, and
	--- `Skill:Activate` returns early while the skill is active. So holding the
	--- guard through a parryable attack is impossible, the window expires before
	--- the hit lands. Without this line the bot silently loses perfect blocks
	--- without failing anywhere.
	local block = config.Skills["Block"]
	if block then
		local holdUntil = block.HoldUntil or {}
		check(
			`{name}: Block releases on perfect-blockable attacks`,
			table.find(holdUntil, "TARGET_PERFECT_BLOCKABLE") ~= nil,
			"HoldUntil must contain TARGET_PERFECT_BLOCKABLE"
		)
	end
end

-- TAG VOCABULARY ------------------------------------------------------------------

--- Skills do not load in `lune` because they pull Roblox in, so the tags are read
--- from the source. The point of the check is not the parser but keeping a
--- hand-written skill from silently drifting away from the vocabulary: the
--- constructor validator rejects such values, and the skill then silently stops
--- working in the bot logic.
local SKILL_FILES = {
	"src/server/skills/Punch.luau",
	"src/server/skills/Barrage.luau",
	"src/server/skills/StandBarrage.luau",
	"src/server/skills/Dash.luau",
	"src/server/skills/Block.luau",
	"src/server/skills/Grab.luau",
	"src/server/skills/Summon.luau",
	"src/server/skills/Standless/Footrest.luau",
	"src/server/skills/Standless/Uppercut.luau",
	"src/server/skills/Standless/CircularKick.luau",
	"src/server/skills/Standless/Counter.luau",
	"src/server/skills/Gerson/Bonk.luau",
	"src/server/skills/Gerson/ShellLaunch.luau",
	"src/server/skills/Undyne/ArcSpearStrike.luau",
	"src/server/skills/Undyne/WaitALittleBit.luau",
}

for _, path in SKILL_FILES do
	local skillId = string.match(path, "([^/]+)%.luau$") :: string
	local source = fs.readFile(path)

	local block = string.match(source, "SkillCharacters%s*=%s*{([^}]*)}")
	check(`{skillId}: has a SkillCharacters block`, block ~= nil, path)

	if block then
		for tag in string.gmatch(block, '"([^"]+)"') do
			check(
				`{skillId}: tag is declared in bot-characters`,
				botCharacters.SkillCharacters[tag] ~= nil,
				`"{tag}" is not in the vocabulary`
			)
		end
	end
end

-- SUMMARY ----------------------------------------------------------------------

print(`[tools.tests.bot-skill-priority] passed: {passed}, failed: {#failures}`)

if #failures > 0 then error(table.concat(failures, "\n"), 0) end

return { passed = passed, failed = #failures }
