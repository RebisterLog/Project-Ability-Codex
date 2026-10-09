--!nolint
--[=[
	Тесты `codec`: JSON-форма blueprints, версии и обратимость.

	Отдельный файл, а не ещё один блок в `structural`: там проверяется валидность
	blueprint'а, здесь — что он переживает `encode`/`decode` без потерь. Это разные
	вопросы, и смешивать их значило бы чинить одну ошибку, переписывая чужой тест.

	Главное здесь — версия 1. Поля `Duration`, `AttackInfoDefaults` и `SoundSlots`
	появились во второй, и читать старые файлы надо уметь: иначе обновление редактора
	убивало бы все несохранённые скиллы пользователя.
]=]

local codec = if game then require(script.Parent.Parent.codec) else require("../codec")

local passed = 0
local failures: { string } = {}

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		return
	end

	table.insert(failures, if detail then `{name} — {detail}` else name)
end

local function equal(name: string, actual: any, expected: any)
	check(name, actual == expected, `expected {tostring(expected)}, got {tostring(actual)}`)
end

local function firstOf(list: { any }): string?
	return if #list > 0 then tostring(list[1]) else nil
end

-- ВСПОМОГАТЕЛЬНОЕ -------------------------------------------------------------

local function block(id: string, blockType: string, startFrame: number?): any
	return {
		Id = id,
		Type = blockType,
		StartFrame = startFrame or 0,
		Properties = {},
	}
end

--- Blueprint версии 2 — то, что пишет текущий редактор.
local function modern(overrides: { [string]: any }?): any
	local built: { [string]: any } = {
		Id = "TestSkill",
		DisplayName = "Test Skill",
		Cooldown = 1,
		AssetSource = "Spec",
		SkillCharacters = { "Hit" },
		AnimationSlots = { { Id = "anim1", Name = "Attack", AnimationId = "Attack1" } },
		SoundSlots = { { Id = "snd1", Name = "Hit", SoundId = "Hit1" } },
		Duration = 240,
		AttackInfoDefaults = { Damage = 10, ["Stun.Duration"] = 1.5 },
		Blocks = { block("b1", "Hitbox", 30) },
		Metadata = { CreatedAt = 1, UpdatedAt = 2, Version = codec.CURRENT_VERSION },
	}

	for key, value in (overrides or {}) :: { [string]: any } do
		built[key] = value
	end
	return built
end

--- Blueprint версии 1: без `SoundSlots`, без `Duration`, без `AttackInfoDefaults`.
local function legacy(): any
	return {
		Id = "OldSkill",
		DisplayName = "Old Skill",
		Cooldown = 3,
		AssetSource = "Spec",
		SkillCharacters = { "Hit" },
		AnimationSlots = { { Id = "anim1", Name = "Attack", AnimationId = "Attack1" } },
		Blocks = {
			{
				Id = "b1",
				Type = "PlaySound",
				StartFrame = 0,
				Properties = { Sound = "Hit1" },
			},
		},
		Metadata = { CreatedAt = 1, UpdatedAt = 2, Version = 1 },
	}
end

-- НОВЫЕ ПОЛЯ ----------------------------------------------------------------

do
	local data = codec.encode(modern())

	check("encode: SoundSlots written", #data.SoundSlots == 1)
	equal("encode: SoundSlot Id", data.SoundSlots[1].Id, "snd1")
	equal("encode: SoundSlot SoundId", data.SoundSlots[1].SoundId, "Hit1")
	equal("encode: Duration", data.Duration, 240)

	local defaults = data.AttackInfoDefaults
	check("encode: AttackInfoDefaults written", type(defaults) == "table")
	equal("encode: bare key", defaults.Damage, 10)
	equal("encode: dotted key", defaults["Stun.Duration"], 1.5)
end

do
	local back = codec.decode(codec.encode(modern()))

	equal("roundtrip: Duration", back.Duration, 240)
	check("roundtrip: SoundSlots", #back.SoundSlots == 1)
	equal("roundtrip: SoundId", back.SoundSlots[1].SoundId, "Hit1")
	equal("roundtrip: AnimationId untouched", back.AnimationSlots[1].AnimationId, "Attack1")
	equal("roundtrip: bare default", back.AttackInfoDefaults.Damage, 10)
	equal("roundtrip: dotted default", back.AttackInfoDefaults["Stun.Duration"], 1.5)
	equal("roundtrip: block start frame", back.Blocks[1].StartFrame, 30)
end

-- Отсутствие поля и ноль — разные вещи. §8 приравнивает отсутствующий ключ к `null`,
-- поэтому пустой `Duration` в JSON был бы неотличим от «длительность ровно ноль»,
-- и переоткрытие файла тихо превратило бы «не задано» в ноль.
--
-- Поля удаляются присваиванием `nil`, а не через `modern({...})`: перезапись
-- `built[key] = nil` ничего не удаляет, и подставленное ранее значение осталось бы на
-- месте — тест прошёл бы, проверяя не то.
do
	local withoutDuration = modern()
	withoutDuration.Duration = nil

	local data = codec.encode(withoutDuration)
	check("encode: absent Duration is not written", data.Duration == nil)
	check("decode: absent Duration stays absent", codec.decode(data).Duration == nil)

	local zero = codec.encode(modern({ Duration = 0 }))
	equal("encode: zero Duration is written", zero.Duration, 0)
	equal("decode: zero Duration survives", codec.decode(zero).Duration, 0)

	local withoutDefaults = modern()
	withoutDefaults.AttackInfoDefaults = nil

	local noDefaults = codec.encode(withoutDefaults)
	check("encode: absent defaults are not written", noDefaults.AttackInfoDefaults == nil)
	check("decode: absent defaults stay absent", codec.decode(noDefaults).AttackInfoDefaults == nil)

	local withoutSoundSlots = modern()
	withoutSoundSlots.SoundSlots = nil

	local emptySlots = codec.encode(withoutSoundSlots)
	check("encode: absent SoundSlots become an empty array", #emptySlots.SoundSlots == 0)
end

-- СОВМЕСТИМОСТЬ С ВЕРСИЕЙ 1 ---------------------------------------------------

do
	local back = codec.decode(codec.encode(legacy()))

	equal("v1: version preserved", back.Metadata.Version, 1)
	equal("v1: Id preserved", back.Id, "OldSkill")
	equal("v1: Cooldown preserved", back.Cooldown, 3)
	check("v1: Duration stays absent", back.Duration == nil)
	check("v1: AttackInfoDefaults stays absent", back.AttackInfoDefaults == nil)
	check("v1: SoundSlots becomes an empty array", #back.SoundSlots == 0)
	equal("v1: direct Sound reference preserved", back.Blocks[1].Properties.Sound, "Hit1")
	check("v1: AnimationSlots preserved", #back.AnimationSlots == 1)
end

do
	-- Файл версии 1 без `Metadata.Version` вовсе: редактор писал его, но hand-written
	-- спец-файлы могли не иметь. Отвергать такой файл нельзя — это не «из будущего».
	local bare = legacy()
	bare.Metadata = {}

	local ok, back = pcall(codec.decode, bare)

	check("v1: a file without a version decodes", ok, firstOf({ tostring(back) }))
	if ok then
		equal(
			"v1: missing version defaults to current",
			back.Metadata.Version,
			codec.CURRENT_VERSION
		)
	end
end

do
	-- Файл из будущего — внятная ошибка вместо тихой потери полей.
	local future = codec.encode(modern())
	future.Metadata.Version = codec.CURRENT_VERSION + 1

	local ok, err = pcall(codec.decode, future)

	check("future: refused", not ok)
	check(
		"future: the message names both versions",
		tostring(err):find("newer than the supported version", 1, true) ~= nil,
		tostring(err)
	)
end

do
	-- Обновление старого файла: `encode` не должен подставлять `Version = 2` в файл,
	-- который пользователь не менял в этой версии редактора. Версия — это версия
	-- формата, а не «какой редактор последний раз открывал».
	local back = codec.decode(codec.encode(legacy()))
	equal("v1: re-encoding does not bump the version", codec.encode(back).Metadata.Version, 1)
end

-- НОВЫЙ BLUEPRINT -----------------------------------------------------------

do
	local fresh = codec.newBlueprint("Fresh")

	equal("newBlueprint: version is current", fresh.Metadata.Version, codec.CURRENT_VERSION)
	check("newBlueprint: no Duration by default", fresh.Duration == nil)
	check("newBlueprint: no AttackInfoDefaults by default", fresh.AttackInfoDefaults == nil)
	check("newBlueprint: SoundSlots present and empty", #fresh.SoundSlots == 0)
	check("newBlueprint: AnimationSlots present and empty", #fresh.AnimationSlots == 0)
end

-- ОТЧЁТ ---------------------------------------------------------------------

print(`[SkillConstructor.tests.codec] passed: {passed}, failed: {#failures}`)
for _, failure in failures do
	print(`  codec: {failure}`)
end

if #failures > 0 then error(`[SkillConstructor.tests.codec] {#failures} failed`, 0) end
