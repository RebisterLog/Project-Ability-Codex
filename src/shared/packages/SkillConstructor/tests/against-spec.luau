--!strict
--- Постоянные тесты проверок по `Spec` (§9, проверки 21–23, 25–27 и W7).
---
--- Файл работает в двух средах: `lune run src/shared/packages/SkillConstructor/tests/against-spec.luau`
--- для CI и `require(ReplicatedStorage.shared.packages.SkillConstructor.tests["against-spec"])`
--- в Studio. Правила проверяются через `checkAgainstSpec` — чистое ядро без
--- Roblox-глобалов, поэтому фикстуры достаточны: ассеты нужны правилам только
--- своими ключами, а не инстансами.
---
--- В Studio дополнительно прогоняется `validateAgainstSpec` — обёртка, которая
--- достаёт настоящий `bot-characters`. Эту часть нельзя покрыть фикстурой: правила
--- 22 проверяют значение тега по живому словарю, иначе тест проверял бы сам себя.

local validator = if game then require(script.Parent.Parent.validator) else require("../validator")

local checkAgainstSpec = validator.checkAgainstSpec
local validateAgainstSpec = validator.validateAgainstSpec

local passed = 0
local failures: { string } = {}

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		return
	end

	table.insert(failures, if detail then `{name} — {detail}` else name)
end

local function countOf(list: { any }, code: string): number
	local total = 0
	for _, issue in list do
		if issue.Code == code then
			total += 1
		end
	end
	return total
end

local function has(list: { any }, code: string): boolean
	return countOf(list, code) > 0
end

local function block(
	id: string,
	blockType: string,
	properties: { [string]: any }?,
	extra: any?
): any
	local built: { [string]: any } = {
		Id = id,
		Type = blockType,
		StartFrame = 0,
		Properties = properties or {},
	}

	for key, value in (extra or {}) :: { [string]: any } do
		built[key] = value
	end
	return built
end

local function blueprint(blocks: { any }?, fields: { [string]: any }?): any
	local built: { [string]: any } = {
		Id = "TestSkill",
		DisplayName = "Test Skill",
		Cooldown = 1,
		AssetSource = "Spec",
		SkillCharacters = { "Hit" },
		AnimationSlots = {
			{ Id = "slot1", Name = "Attack", AnimationId = "Attack" },
		},
		Blocks = blocks or {},
		Metadata = { Version = 1 },
	}

	for key, value in (fields or {}) :: { [string]: any } do
		built[key] = value
	end
	return built
end

--- Значения-пустышки достаточны: правила спрашивают только про ключ.
local function specData(withStand: boolean?): any
	local assets: { [string]: any } = {
		Animations = { Attack = {} },
		Sounds = { Hit = {} },
		Models = { Spark = {} },
	}

	if withStand then
		assets.Stand = {
			Animations = { Attack = {} },
			Sounds = { Hit = {} },
			Models = { Spark = {} },
		}
	end

	return { Id = "TestSpec", Assets = assets }
end

local FIXTURE_TAGS = { Hit = "Hit", Grab = "Grab" }

local function run(blocks: { any }?, fields: { [string]: any }?, withStand: boolean?)
	return checkAgainstSpec(blueprint(blocks, fields), {
		specData = specData(withStand),
		validTags = FIXTURE_TAGS,
	})
end

-- Позитив: всё разрешается.
do
	local result = run({
		block("b1", "Hitbox"),
		block("b2", "PlayAnimation", { Slot = "slot1" }),
		block("b3", "PlaySound", { Sound = "Hit" }),
		block("b4", "EmitParticle", { Particle = "Spark" }),
		block("b5", "EmitFolder", { Folder = "Spark" }),
	})

	local errorMessage = if #result.errors > 0 then result.errors[1].Message else nil
	local warningMessage = if #result.warnings > 0 then result.warnings[1].Message else nil

	check("valid spec blueprint has no errors", #result.errors == 0, errorMessage)
	check("valid spec blueprint has no warnings", #result.warnings == 0, warningMessage)
end

-- 21. SkillCharacters обязателен при наличии Hitbox
do
	local hitbox = { block("b1", "Hitbox") }
	check("E21: Hitbox without tags", has(run(hitbox, { SkillCharacters = {} }).errors, "E21"))
	check(
		"E21: Hitbox with tags accepted",
		not has(run(hitbox, { SkillCharacters = { "Hit" } }).errors, "E21")
	)

	-- Вложенный Hitbox тоже требует тегов: поиск идёт по всему дереву.
	local nestedHitbox = {
		block("r1", "Repeat", nil, {
			StartFrame = 0,
			EndFrame = 5,
			Children = { Body = { block("b1", "Hitbox") } },
		}),
	}
	check(
		"E21: nested Hitbox without tags",
		has(run(nestedHitbox, { SkillCharacters = {} }).errors, "E21")
	)

	-- Без Hitbox пустой список — законное состояние.
	local noHitbox = { block("b1", "PlaySound", { Sound = "Hit" }) }
	check(
		"E21: tags not required without Hitbox",
		not has(run(noHitbox, { SkillCharacters = {} }).errors, "E21")
	)
end

-- 22. Теги из bot-characters.SkillCharacters
do
	check("E22: unknown tag", has(run(nil, { SkillCharacters = { "Ghost" } }).errors, "E22"))
	check(
		"E22: every unknown tag reported",
		countOf(run(nil, { SkillCharacters = { "Ghost", "Phantom" } }).errors, "E22") == 2
	)
	check(
		"E22: known tags accepted",
		not has(run(nil, { SkillCharacters = { "Hit", "Grab" } }).errors, "E22")
	)
end

-- 23. PlayAnimation → Assets.Animations
do
	check(
		"E23: known animation",
		not has(run({ block("b1", "PlayAnimation", { Slot = "slot1" }) }).errors, "E23")
	)

	local ghostSlot = blueprint({ block("b1", "PlayAnimation", { Slot = "slot1" }) }, {
		AnimationSlots = { { Id = "slot1", Name = "Attack", AnimationId = "Ghost" } },
	})
	local result = checkAgainstSpec(ghostSlot, {
		specData = specData(),
		validTags = FIXTURE_TAGS,
	})

	check("E23: missing animation", has(result.errors, "E23"))
	check("E23: single issue per slot", countOf(result.errors, "E23") == 1)
end

-- 25 / 26 / 27. Assets.Sounds и Assets.Models
do
	check(
		"E25: known sound",
		not has(run({ block("b1", "PlaySound", { Sound = "Hit" }) }).errors, "E25")
	)
	check(
		"E25: missing sound",
		has(run({ block("b1", "PlaySound", { Sound = "Ghost" }) }).errors, "E25")
	)

	check(
		"E26: known model",
		not has(run({ block("b1", "EmitParticle", { Particle = "Spark" }) }).errors, "E26")
	)
	check(
		"E26: missing model",
		has(run({ block("b1", "EmitParticle", { Particle = "Ghost" }) }).errors, "E26")
	)

	check(
		"E27: known folder",
		not has(run({ block("b1", "EmitFolder", { Folder = "Spark" }) }).errors, "E27")
	)
	check(
		"E27: missing folder",
		has(run({ block("b1", "EmitFolder", { Folder = "Ghost" }) }).errors, "E27")
	)
end

-- Обход дерева: ассеты нужны и вложенным блокам, путь в ошибке указывает на них.
do
	local nested = run({
		block("b1", "ProcessAttack", nil, {
			Children = {
				OnSuccess = { block("c1", "PlaySound", { Sound = "Ghost" }) },
			},
		}),
	})

	local issue = nested.errors[1] :: any
	check("nested: E25 found", has(nested.errors, "E25"))
	check("nested: BlockId is the child", issue.BlockId == "c1")
	check(
		"nested: Path points into Children",
		issue.Path[1] == "Blocks"
			and issue.Path[2] == 1
			and issue.Path[3] == "Children"
			and issue.Path[4] == "OnSuccess"
			and issue.Path[5] == 1
	)
end

-- W7. AssetSource = Stand
do
	local sound = { block("b1", "PlaySound", { Sound = "Hit" }) }
	local stand = { SkillCharacters = { "Hit" }, AssetSource = "Stand" }

	local missingStand = run(sound, stand)
	check("W7: Stand without Assets.Stand", has(missingStand.warnings, "W7"))
	check("W7: warning is not an error", not has(missingStand.errors, "W7"))
	check("W7: assets still resolve from base", not has(missingStand.errors, "E25"))

	local withStand = run(sound, stand, true)
	check("W7: not reported when Stand exists", not has(withStand.warnings, "W7"))
	check("W7: assets resolve from Stand", not has(withStand.errors, "E25"))

	-- `Stand` есть, но ключа в нём нет: это уже E25, а не второй код про то же
	-- самое — иначе пользователь увидел бы одну проблему дважды.
	local brokenStand = checkAgainstSpec(blueprint(sound, stand), {
		specData = {
			Id = "TestSpec",
			Assets = {
				Animations = { Attack = {} },
				Sounds = { Hit = {} },
				Models = { Spark = {} },
				Stand = { Animations = {}, Sounds = {}, Models = {} },
			},
		},
		validTags = FIXTURE_TAGS,
	})
	check("W7: missing key in Stand is E25", has(brokenStand.errors, "E25"))
	check("W7: no duplicate warning", not has(brokenStand.warnings, "W7"))

	check("W7: not reported for AssetSource=Spec", not has(run(sound).warnings, "W7"))
end

-- Только в Studio: обёртка обязана тянуть настоящий `bot-characters`.
if game then
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local botCharacters = require(ReplicatedStorage.shared["bot-characters"])

	local function live(blocks: { any }?, fields: { [string]: any }?): { [string]: any }
		return validateAgainstSpec(blueprint(blocks, fields), specData())
	end

	check(
		"live: real Hit tag accepted",
		not has(live(nil, { SkillCharacters = { "Hit" } }).errors, "E22")
	)
	check(
		"live: real Grab tag accepted",
		not has(live(nil, { SkillCharacters = { "Grab" } }).errors, "E22")
	)
	check(
		"live: real tag vocabulary is loaded",
		botCharacters.SkillCharacters.Grab ~= nil and botCharacters.SkillCharacters.Hit ~= nil
	)

	local hitbox = { block("b1", "Hitbox") }
	check("live: E21 on real data", has(live(hitbox, { SkillCharacters = {} }).errors, "E21"))
end

print(`[SkillConstructor.tests.against-spec] passed: {passed}, failed: {#failures}`)

if #failures > 0 then error(table.concat(failures, "\n"), 0) end

return { passed = passed, failed = #failures }
