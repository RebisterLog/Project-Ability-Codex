--!strict
--- Постоянные тесты эмиттера (§7, §10).
---
--- Файл работает в двух средах: `lune run src/shared/packages/SkillConstructor/tests/emitter.luau`
--- для CI и `require(ReplicatedStorage.shared.packages.SkillConstructor.tests.emitter)`
--- в Studio. Отсюда shim на `emitter` и `codec` — в `lune` у теста нет
--- `script.Parent`, а в игре соседние по файловой системе модули недоступны по
--- относительному пути.
---
--- На вход эмиттеру всегда подаётся результат `codec.encode`, то есть настоящая
--- JSON-форма: группы свойств вложенными таблицами. Проверки идут по трём
--- наблюдаемым выходам: `Source` (текст модуля), `Preview` (кадры для UI) и
--- `Errors` (проблемы, которые UI показывает пользователю).
---
--- Смысл каждой группы проверок — не «строка присутствует», а инвариант, который
--- иначе ломается тихо: терминатор обязан быть последним кадром, диапазон — иметь
--- `end`, цикл по целям не должен появляться дважды, а сломанный блок не должен
--- ронять генерацию.

local codec = if game then require(script.Parent.Parent.codec) else require("../codec")
local emitter = if game then require(script.Parent.Parent.emitter) else require("../emitter")

local emit = emitter.emit
local previewOf = emitter.preview

local passed = 0
local failures: { string } = {}

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		return
	end

	table.insert(failures, if detail then `{name} — {detail}` else name)
end

-- ВСПОМОГАТЕЛЬНОЕ -------------------------------------------------------------

local function V3(x: number, y: number, z: number): any
	return { ["$"] = "V3", x = x, y = y, z = z }
end

local function CF(px: number, py: number, pz: number, rx: number?, ry: number?, rz: number?): any
	return { ["$"] = "CF", px = px, py = py, pz = pz, rx = rx or 0, ry = ry or 0, rz = rz or 0 }
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
		AnimationSlots = {},
		SoundSlots = {},
		Blocks = blocks or {},
		Metadata = { Version = 1 },
	}

	for key, value in (fields or {}) :: { [string]: any } do
		built[key] = value
	end
	return built
end

--- Blueprint → JSON-форма → результат эмиттера.
local function run(blocks: { any }?, fields: { [string]: any }?): any
	return emit(codec.encode(blueprint(blocks, fields)))
end

local function has(list: { any }, code: string): boolean
	for _, issue in list do
		if issue.Code == code then return true end
	end
	return false
end

local function count(source: string, needle: string): number
	local total = 0
	local from = 1

	while true do
		local at = string.find(source, needle, from, true)
		if at == nil then break end

		total += 1
		from = at + #needle
	end

	return total
end

local function contains(source: string, needle: string): boolean
	return string.find(source, needle, 1, true) ~= nil
end

--- Позиция последнего вхождения `needle`.
local function lastIndex(source: string, needle: string): number
	local at = 0
	local from = 1

	while true do
		local found = string.find(source, needle, from, true)
		if found == nil then break end

		at = found
		from = found + 1
	end

	return at
end

--- Строки `source` с последней совпавшей с `needle`. Разбор строк сделан вручную:
--- `string.split` в Roblox возвращает таблицу частей, а в `lune` — итератор пар,
--- поэтому один и тот же `for a, b in` в этих средах даёт разные значения.
local function lastLineWith(source: string, needle: string): string
	local found = ""
	local from = 1

	while true do
		local newline = string.find(source, "\n", from, true)
		local line = if newline
			then string.sub(source, from, newline - 1)
			else string.sub(source, from)

		if contains(line, needle) then found = line end
		if newline == nil then break end

		from = newline + 1
	end

	return found
end

local function previewFrameAt(result: any, frame: number): any
	for _, item in result.Preview do
		if item.Frame == frame then return item end
	end
	return nil
end

-- 1. КАРКАС МОДУЛЯ -----------------------------------------------------------

do
	local result = run(nil)
	local source = result.Source

	check(
		"empty blueprint has no errors",
		#result.Errors == 0,
		result.Errors[1] and result.Errors[1].Message
	)
	check("empty blueprint has a source", #source > 0)
	check("source starts with --!native", string.sub(source, 1, 9) == "--!native")
	check("source has --!optimize 2", contains(source, "--!optimize 2"))
	check("source has no file header comment", not contains(source, "--[["))
	check("source returns the skill", contains(source, "return Skill"))
	check("source defines onInit", contains(source, "function Skill:onInit()"))
	check("source defines Activate", contains(source, "function Skill:Activate()"))
	check("source defines Interrupt", contains(source, "function Skill:Interrupt()"))
	check("source defines onDestroy", contains(source, "function Skill:onDestroy()"))
	check("source has DisplayName", contains(source, 'DisplayName = "Test Skill",'))
	check("source has Cooldown", contains(source, "Cooldown = 1,"))
	check("source has SkillCharacters", contains(source, 'SkillCharacters = { "Hit" },'))
	check(
		"empty AttackInfo for a skill without attacks",
		contains(source, "AttackInfo = {},"),
		lastLineWith(source, "AttackInfo")
	)

	-- Пустой скилл не должен тянуть лишние зависимости (§10).
	check("empty skill has no Enums", not contains(source, "local Enums"))
	check("empty skill has no Players", not contains(source, "local Players"))
	check("empty skill has no VFXService", not contains(source, 'GetService("VFXService")'))
	check("empty skill has no StandService", not contains(source, "StandService"))
	check("empty skill has no NextUuid", not contains(source, "NextUuid"))
end

-- 2. FRAMES: ПРЕАМБУЛА, ТЕРМИНАТОР, ПОРЯДОК ---------------------------------

do
	-- Длина sequence не меньше MIN_FRAMES, а `Wait` её увеличивает (§7, пункт 6).
	local waited = run({ block("w1", "Wait", nil, { StartFrame = 120 }) })
	local empty = run(nil)

	check(
		"Wait alone has no errors",
		#waited.Errors == 0,
		waited.Errors[1] and waited.Errors[1].Message
	)
	check(
		"Wait extends maxFrame",
		contains(waited.Source, "{ 120 },"),
		lastLineWith(waited.Source, "{ 120")
	)
	check("Wait produces no empty callback", not contains(waited.Source, "EMIT"))
	check(
		"empty skill ends at MIN_FRAMES",
		contains(empty.Source, "{ 60 },"),
		lastLineWith(empty.Source, "{ 60 },")
	)
	check("Wait does not shrink the skill", not contains(empty.Source, "{ 120 },"))
	check(
		"only one terminator is printed",
		count(waited.Source, "{ 120 },") == 1,
		tostring(count(waited.Source, "{ 120 },"))
	)

	local terminatorAt = lastIndex(waited.Source, "{ 120 },")
	check(
		"nothing runs after the terminator",
		not contains(string.sub(waited.Source, terminatorAt), "function(seq)"),
		lastLineWith(waited.Source, "{ 120 },")
	)
end

do
	-- Кадры идут по возрастанию, терминатор — последний.
	local result = run({
		block("b3", "SetMaxWalkSpeed", { Value = 8 }, { StartFrame = 40 }),
		block("b1", "SetMaxWalkSpeed", { Value = 4 }, { StartFrame = 10 }),
	})
	local source = result.Source

	check(
		"frames are sorted",
		string.find(source, "\t\t\t\t10,", 1, true) < string.find(source, "\t\t\t\t40,", 1, true)
	)

	local terminatorAt = lastIndex(source, "{ 60 },")
	check(
		"terminator is the last frame",
		not contains(string.sub(source, terminatorAt), "function(seq)"),
		lastLineWith(source, "{ 60 },")
	)
end

do
	-- Преамбула обязана быть первым элементом `Frames`, иначе `ProcessAttack` на
	-- кадре 0 увидит `seq.Ctx = nil`.
	local result = run({ block("s1", "SetMaxWalkSpeed", { Value = 8 }, { StartFrame = 0 }) })

	check(
		"preamble is the first frame",
		contains(
			result.Source,
			"Frames = {\n\t\t\t{\n\t\t\t\t0,\n\t\t\t\tfunction(seq)\n\t\t\t\t\tseq.Ctx = { Targets = {} }"
		),
		lastLineWith(result.Source, "seq.Ctx")
	)
end

do
	-- Блоки одного кадра сливаются в один callback (§7, пункт 4).
	local result = run({
		block("a1", "SetMaxWalkSpeed", { Value = 8 }, { StartFrame = 5 }),
		block("a2", "SetMinWalkSpeed", { Value = 2 }, { StartFrame = 5 }),
	})
	local source = result.Source

	check(
		"same-frame blocks merge into one callback",
		count(source, "function(seq)") == 2,
		tostring(count(source, "function(seq)"))
	)
	check("merged body keeps both parameters", contains(source, 'AddParameter("MaxWalkSpeed", 8)'))
	check("merged body keeps second parameter", contains(source, 'AddParameter("MinWalkSpeed", 2)'))
end

-- 3. REPEAT И ДИАПАЗОНЫ ------------------------------------------------------

do
	local result = run({
		block("r1", "Repeat", nil, {
			StartFrame = 10,
			EndFrame = 90,
			Children = { Body = { block("r2", "SetMaxWalkSpeed", { Value = 8 }) } },
		}),
	})
	local source = result.Source

	check(
		"Repeat has no errors",
		#result.Errors == 0,
		result.Errors[1] and result.Errors[1].Message
	)
	check("Repeat prints the range check", contains(source, "if frame >= 10 and frame <= 90 then"))
	check("Repeat becomes a range frame", contains(source, "function(seq, frame)"))
	check("Repeat keeps its end frame", contains(source, "\t\t90,"))
	check("Repeat can extend the skill", contains(source, "{ 90 },"), lastLineWith(source, "{ 90"))
	check(
		"Repeat is one frame element",
		count(source, "function(seq, frame)") == 1,
		tostring(count(source, "function(seq, frame)"))
	)
end

do
	-- Вложенный `Repeat` обязан проверять диапазон в теле: иначе он выполнится один
	-- раз, на кадре родителя.
	local result = run({
		block("r1", "Repeat", nil, {
			StartFrame = 10,
			EndFrame = 40,
			Children = {
				Body = {
					block("r2", "Repeat", nil, {
						StartFrame = 20,
						EndFrame = 30,
						Children = { Body = { block("r3", "SetMaxWalkSpeed", { Value = 8 }) } },
					}),
				},
			},
		}),
	})
	local source = result.Source

	check(
		"nested Repeat checks its own range",
		contains(source, "if frame >= 20 and frame <= 30 then")
	)
	check(
		"nested Repeat stays inside the parent range",
		count(source, "function(seq, frame)") == 1,
		tostring(count(source, "function(seq, frame)"))
	)
end

do
	-- Вложенный блок не может начаться раньше родителя (§7, пункт 1).
	local result = run({
		block("r1", "Repeat", nil, {
			StartFrame = 30,
			EndFrame = 40,
			Children = {
				Body = { block("c1", "SetMaxWalkSpeed", { Value = 8 }, { StartFrame = 5 }) },
			},
		}),
	})
	local source = result.Source

	check("nested start is clamped to the parent", not contains(source, "frame >= 5"))
	check("clamped block still prints", contains(source, 'AddParameter("MaxWalkSpeed", 8)'))
end

do
	local result = run({
		block("r1", "Repeat", nil, {
			StartFrame = 40,
			EndFrame = 10,
			Children = { Body = { block("c1", "SetMaxWalkSpeed", { Value = 8 }) } },
		}),
	})
	check("Repeat ending before it starts is reported", has(result.Errors, "EMIT_FRAME"))
end

-- 4. BRANCH ------------------------------------------------------------------

do
	local result = run({
		block("b1", "Branch", { Condition = "seq.Speed > 1" }, {
			Children = {
				True = { block("t1", "SetMaxWalkSpeed", { Value = 8 }) },
				False = { block("f1", "SetMinWalkSpeed", { Value = 2 }) },
			},
		}),
	})
	local source = result.Source

	check(
		"Branch has no errors",
		#result.Errors == 0,
		result.Errors[1] and result.Errors[1].Message
	)
	check("Branch keeps the condition verbatim", contains(source, "if (seq.Speed > 1) then"))
	check("Branch prints else", contains(source, "\telse"))
	check("Branch fills both arms", contains(source, 'AddParameter("MaxWalkSpeed", 8)'))
	check("Branch fills the false arm", contains(source, 'AddParameter("MinWalkSpeed", 2)'))
end

do
	local result = run({
		block("b1", "Branch", { Condition = "seq.Speed > 1" }, {
			Children = { False = { block("f1", "SetMinWalkSpeed", { Value = 2 }) } },
		}),
	})
	local source = result.Source

	check(
		"Branch without True inverts the condition",
		contains(source, "if not (seq.Speed > 1) then")
	)
	check("Branch without True has no else", not contains(source, "\telse"))
end

do
	local result = run({
		block(
			"b1",
			"Branch",
			{},
			{ Children = { True = { block("t1", "SetMaxWalkSpeed", { Value = 8 }) } } }
		),
	})
	check("Branch without a condition is reported", has(result.Errors, "EMIT_VALUE"))
	check("Branch without a condition prints nothing", not contains(result.Source, "if ("))
end

-- 5. PROCESSATTACK -----------------------------------------------------------

do
	local result = run({
		block("p1", "ProcessAttack", {
			Damage = 15,
			Stun = { Duration = 0.7, Priority = "Medium" },
			Block = { Blockable = true },
		}, {
			StartFrame = 15,
			Children = {
				OnSuccess = { block("c1", "SetMaxWalkSpeed", { Value = 8 }) },
			},
		}),
	})
	local source = result.Source

	check(
		"ProcessAttack has no errors",
		#result.Errors == 0,
		result.Errors[1] and result.Errors[1].Message
	)
	check("ProcessAttack reads the target list", contains(source, "seq.Ctx and seq.Ctx.Targets or"))
	check("ProcessAttack calls Attack", contains(source, "CombatService:Attack({"))
	check("ProcessAttack passes Attacker", contains(source, "Attacker = character,"))
	check("ProcessAttack passes Victim", contains(source, "Victim = Target,"))
	check("ProcessAttack uses andThen", contains(source, "):andThen(function(Data)"))
	check(
		"ProcessAttack guards OnSuccess",
		contains(source, "if Data.State.Success and Data.State.Continue then")
	)
	check("ProcessAttack fills the slot body", contains(source, 'AddParameter("MaxWalkSpeed", 8)'))
	check("Info keeps Damage", contains(source, "Damage = 15,"))
	check("Info reads the nested Stun group", contains(source, "Duration = 0.7,"))
	check("Info maps the enum to Enums", contains(source, "Priority = Enums.Stun.Medium,"))
	check("Info keeps a partial Block group", contains(source, "Blockable = true,"))
	check("Info skips empty groups", not contains(source, "PerfectBlockable"))
	check("Info opens the Stun group", contains(source, "Stun = {"))
end
do
	-- `SkipBlocked` сужает ТОЛЬКО `OnSuccess`. Раньше обычный блок давал
	-- `Success = true, Continue = true, Blocked = true` (`Block.luau:42`), а слоты
	-- печатались независимыми `if`, не `elseif` — атака, блокнутая целью, исполняла и
	-- успех, и блок одновременно, то есть выглядела как попадание.
	local result = run({
		block("a1", "ProcessAttack", { Damage = 10, SkipBlocked = true }, {
			Children = {
				OnSuccess = { block("s1", "SetMaxWalkSpeed", { Value = 8 }) },
				OnBlocked = { block("b1", "SetMaxWalkSpeed", { Value = 4 }) },
			},
		}),
	})
	local source = result.Source

	check("SkipBlocked has no errors", #result.Errors == 0)
	check(
		"SkipBlocked excludes Blocked from OnSuccess",
		contains(source, "if Data.State.Success and Data.State.Continue ")
			and contains(source, "and not Data.State.Blocked ")
			and contains(source, "and not Data.State.PerfectBlocked then")
	)
	check("OnBlocked keeps its own guard", contains(source, "if Data.State.Blocked then"))
end

do
	-- Без поля поведение прежнее: сужать guard нельзя молча, это изменило бы смысл
	-- всех уже написанных скиллов.
	local result = run({
		block("a1", "ProcessAttack", { Damage = 10 }, {
			Children = {
				OnSuccess = { block("s1", "SetMaxWalkSpeed", { Value = 8 }) },
			},
		}),
	})

	check(
		"without SkipBlocked the guard is untouched",
		contains(result.Source, "if Data.State.Success and Data.State.Continue then")
	)
	check(
		"without SkipBlocked no Blocked check appears",
		not contains(result.Source, "not Data.State.Blocked")
	)
end

do
	-- Явный `false` — то же, что отсутствие: поле по умолчанию `false`, и UI обязана
	-- уметь его снять, не оставляя «включённым» после снятия галочки.
	local result = run({
		block("a1", "ProcessAttack", { Damage = 10, SkipBlocked = false }, {
			Children = {
				OnSuccess = { block("s1", "SetMaxWalkSpeed", { Value = 8 }) },
			},
		}),
	})

	check(
		"SkipBlocked=false leaves the guard alone",
		contains(result.Source, "if Data.State.Success and Data.State.Continue then")
	)
end

do
	-- Поле принадлежит секции `AttackInfo`, а не слоту, поэтому его значение не должно
	-- попадать в печатаемый `Info`: иначе получился бы неизвестный ключ боевой таблицы.
	local result = run({
		block("a1", "ProcessAttack", { Damage = 10, SkipBlocked = true }, {
			Children = {
				OnSuccess = { block("s1", "SetMaxWalkSpeed", { Value = 8 }) },
			},
		}),
	})

	check("SkipBlocked is not printed into Info", not contains(result.Source, "SkipBlocked ="))
end

do
	-- Без вложенных слотов `andThen` всё равно нужен: `Attack` возвращает промис.
	local result = run({ block("p1", "ProcessAttack", { Damage = 1 }) })
	check(
		"ProcessAttack without slots still has andThen",
		contains(result.Source, "):andThen(function() end)")
	)
	check("ProcessAttack without slots has no errors", #result.Errors == 0)
end

do
	-- `AttackInfo` шапки берётся из `ProcessAttack`: без него `Grab.luau:74` и
	-- `TEMPLATE.luau:57` читают `nil`.
	local result = run({
		block("p1", "ProcessAttack", { Damage = 42, Stun = { Duration = 1, Priority = "High" } }),
	})
	local source = result.Source

	check("AttackInfo is built from ProcessAttack", contains(source, "\tAttackInfo = {"))
	check("AttackInfo keeps Damage", contains(source, "Damage = 42,"))
	check("AttackInfo keeps Stun", contains(source, "Priority = Enums.Stun.High,"))
	check("AttackInfo pulls in Enums", contains(source, "local Enums"))
end

do
	-- Первое непустое поле побеждает (§6): два разных удара нельзя свести к одному.
	local result = run({
		block("p1", "ProcessAttack", { Damage = 42 }),
		block("p2", "ProcessAttack", { Damage = 7 }),
	})
	local source = result.Source

	check("first Damage wins in AttackInfo", contains(source, "Damage = 42,"))
	check("second Damage is not lost", contains(source, "Damage = 7,"))
end

-- 6. ЦИКЛ ПО ЦЕЛЯМ -----------------------------------------------------------

do
	-- `CreateGrab` требует жертву, поэтому вне `ProcessAttack` эмиттер оборачивает
	-- его циклом сам.
	local result = run({
		block(
			"g1",
			"CreateGrab",
			{ BindMode = "RootToRoot", Offset = CF(0, 0, -4) },
			{ StartFrame = 5 }
		),
	})
	local source = result.Source

	check(
		"CreateGrab outside Attack is wrapped in a loop",
		contains(source, "for _, Target in Targets1 do")
	)
	check("CreateGrab has one loop only", count(source, "for _, Target in Targets1 do") == 1)
	check("CreateGrab binds RootPart", contains(source, "Part0 = RootPart,"))
	check("CreateGrab binds the target root", contains(source, "Part1 = Target.RootPart,"))
	check(
		"CreateGrab passes the data table",
		contains(source, "CombatService:CreateGrab(character, Target, GrabData1)")
	)
	check("CreateGrab prints CFrame", contains(source, "CFrame.new(0, 0, -4)"))
	check(
		"CreateGrab target loop has no errors",
		#result.Errors == 0,
		result.Errors[1] and result.Errors[1].Message
	)
end

do
	-- Внутри `ProcessAttack` цель уже есть — второй цикл был бы дублем.
	local result = run({
		block("p1", "ProcessAttack", { Damage = 1 }, {
			Children = {
				OnSuccess = { block("g1", "CreateGrab", { BindMode = "None" }) },
			},
		}),
	})
	local source = result.Source

	check("CreateGrab inside Attack is not wrapped again", count(source, "for _, Target in") == 1)
	check("CreateGrab inside Attack binds nothing", not contains(source, "Part1 ="))
end

do
	local result = run({ block("v1", "EmitParticle", { Particle = "Hit", Origin = "Target" }) })
	local source = result.Source

	check(
		"EmitParticle on target is wrapped in a loop",
		contains(source, "for _, Target in Targets1 do")
	)
	check(
		"EmitParticle on target uses the target root",
		contains(source, "Origin = Target.RootPart,")
	)
	check("EmitParticle on target has no errors", #result.Errors == 0)
end

do
	local result = run({ block("v1", "EmitParticle", { Particle = "Hit", Origin = "Caster" }) })
	local source = result.Source

	check("EmitParticle on caster is not wrapped", not contains(source, "for _, Target in"))
	check(
		"EmitParticle on caster uses the caster root",
		contains(source, "Origin = RootPart.CFrame,")
	)
end

do
	local result = run({ block("v1", "EmitFolder", { Folder = "Trail", Origin = "Target" }) })
	local source = result.Source

	check(
		"EmitFolder on target is wrapped in a loop",
		contains(source, "for _, Target in Targets1 do")
	)
	check("EmitFolder on target uses the target model", contains(source, "Target.instance"))
	check("EmitFolder stringifies its uuid", contains(source, "tostring(NextUuid())"))
end

-- 7. VFX И ЗАВИСИМОСТИ -------------------------------------------------------

do
	local result = run({ block("v1", "PlayAnimation", { Slot = "a1" }) }, {
		AnimationSlots = { { Id = "a1", Name = "Punch", AnimationId = "Punch", Speed = 1 } },
	})
	local source = result.Source

	check(
		"PlayAnimation has no errors",
		#result.Errors == 0,
		result.Errors[1] and result.Errors[1].Message
	)
	check(
		"PlayAnimation resolves the slot",
		contains(source, 'Animation = Anims["Punch"].Animation,')
	)
	check("PlayAnimation falls back to the slot speed", contains(source, "Speed = 1,"))
	check("PlayAnimation pulls Anims", contains(source, "local Anims = self.Assets.Animations"))
	check("PlayAnimation pulls Players", contains(source, "local Players = game:GetService"))
	check("PlayAnimation pulls VFXService", contains(source, 'GetService("VFXService")'))
	check("PlayAnimation stops itself", contains(source, '"Animation", character.instance'))
	check("PlayAnimation registers cleanup", contains(source, "seq.Cleaner:Add(function()"))
end

do
	local result = run({ block("v1", "StopAnimation", { Slot = "a1", FadeTime = 0.5 }) }, {
		AnimationSlots = { { Id = "a1", Name = "Punch", AnimationId = "Punch" } },
	})
	local source = result.Source

	check("StopAnimation prints FadeTime", contains(source, "FadeTime = 0.5,"))
	check(
		"StopAnimation keeps the slot key",
		contains(source, 'Animation = Anims["Punch"].Animation,')
	)
end

do
	local result = run({ block("v1", "PlaySound", { Sound = "Hit", Volume = 0.5 }) })
	local source = result.Source

	check("PlaySound has no errors", #result.Errors == 0)
	check("PlaySound prints the asset", contains(source, 'Sound = Sounds["Hit"].Sound,'))
	check("PlaySound prints Volume", contains(source, "Volume = 0.5,"))
	check("PlaySound pulls Sounds", contains(source, "local Sounds = self.Assets.Sounds"))
	check("PlaySound stops itself", contains(source, '"Sound", RootPart, Sounds["Hit"].Sound)'))
end

do
	-- Слот — основной путь: ключ берётся из `SoundSlots`, прямой `Sound` не
	-- указывается, и блок ссылается только на локальный GUID.
	local result = run({
		block("v1", "PlaySound", { Slot = "synth", Volume = 0.8 }),
	}, { SoundSlots = { { Id = "synth", Name = "synth", SoundId = "BonkSlam" } } })
	local source = result.Source

	check("PlaySound via Slot has no errors", #result.Errors == 0)
	check(
		"PlaySound via Slot prints the asset",
		contains(source, 'Sound = Sounds["BonkSlam"].Sound,')
	)
	check("PlaySound via Slot stops itself", contains(source, 'Sounds["BonkSlam"].Sound'))
end

do
	-- `StopSound` — посредстоп звука: один `StopEffect`, без `Cleaner`, без нового
	-- `StartEffect`.
	local result = run({
		block("v1", "StopSound", { Slot = "synth" }),
	}, { SoundSlots = { { Id = "synth", Name = "synth", SoundId = "BonkSlam" } } })
	local source = result.Source

	check("StopSound has no errors", #result.Errors == 0)
	check(
		"StopSound stops the effect",
		contains(
			source,
			'VFXService:StopEffect(Players:GetPlayers(), "Sound", RootPart, Sounds["BonkSlam"].Sound)'
		)
	)
	check(
		"StopSound does not replay the sound",
		not contains(source, 'StartEffect(Players:GetPlayers(), "Sound"')
	)
end

do
	-- Совместимость v1: без слота `Sound` всё ещё работает в обоих блоках.
	local play = run({ block("v1", "PlaySound", { Sound = "Hit" }) })
	local stop = run({ block("v1", "StopSound", { Sound = "Hit" }) })

	check(
		"PlaySound legacy Sound still emits",
		contains(play.Source, 'Sound = Sounds["Hit"].Sound,')
	)
	check("StopSound legacy Sound still emits", contains(stop.Source, 'Sounds["Hit"].Sound'))
end

do
	-- `Duration` как пол. Проверяется `maxFrame`, потому что именно из него эмиттер
	-- строит `Frames`; искать в исходнике строку `Frames = 240` означало бы проверять
	-- формат вывода вместо самого правила.
	local raised =
		emitter.maxFrame(codec.encode(blueprint({ block("v1", "Hitbox") }, { Duration = 240 })))
	local baseline = emitter.maxFrame(codec.encode(blueprint({ block("v1", "Hitbox") })))

	check("Duration raises the sequence length", raised == 240)
	check("Duration absent falls back to MIN_FRAMES", baseline == 60)
end

do
	-- Пол, а не потолок: `Duration` короче последнего шага игнорируется, иначе эмиттер
	-- напечатал бы кадр за пределами `Frames` и `verifyEntries` упал бы.
	local long = emitter.maxFrame(codec.encode(blueprint({
		block("v1", "Hitbox", nil, { StartFrame = 600 }),
	}, { Duration = 30 })))

	check("Duration below the tree is ignored", long == 600)
end

do
	-- Не-число не должно превращаться в пол. `frameFloor` читает `type(requested) ==
	-- "number"`, так что строка молча дала бы `MIN_FRAMES` — ровно то, чего
	-- пользователь не ожидал. Сообщение об этом даёт валидатор (E2, см. structural), а
	-- не эмиттер: он не проверяет вход и просто не применяет негодное значение.
	local encoded = codec.encode(blueprint({ block("v1", "Hitbox") }, { Duration = "240" }))
	local emitted = emitter.maxFrame(encoded)

	check("Duration as a string does not raise the floor", emitted == 60)
	check(
		"Duration as a string is not treated as a number",
		type((encoded :: any).Duration) ~= "number" or (encoded :: any).Duration == nil
	)
end

do
	-- `AttackInfoDefaults` заполняет шапку скилла. Значение, которое блок не переопределяет,
	-- берётся отсюда; переопределённое — остаётся своим.
	local seeded = run(
		{ block("v1", "ProcessAttack", { Damage = 42 }) },
		{ AttackInfoDefaults = { Damage = 10, ["Stun.Duration"] = 1.5 } }
	)
	local source = seeded.Source

	check("AttackInfoDefaults has no errors", #seeded.Errors == 0)
	check("AttackInfoDefaults seeds a bare field", contains(source, "Damage = 10,"))
	check("AttackInfoDefaults seeds a dotted field", contains(source, "Duration = 1.5,"))
	check("the block's own value wins", contains(source, "Damage = 42,"))
	check("the block's value is not duplicated", count(source, "Damage = 10,") == 1)
end

do
	-- Непримитивные значения `isPrintable` отбрасывает: секция не должна появляться в
	-- шапке из-за значения, которое эмиттер всё равно не напечатал бы.
	local noise = run(
		{ block("v1", "ProcessAttack", { Damage = 42 }) },
		{ AttackInfoDefaults = { Damage = function() end } }
	)

	check(
		"AttackInfoDefaults skips unprintable values",
		not contains(noise.Source, "Damage = function")
	)
end

do
	local result = run({
		block("v1", "Highlight", {
			FillColor = { ["$"] = "C3", r = 1, g = 0, b = 0 },
			Lifetime = 0.5,
		}),
	})
	local source = result.Source

	check("Highlight prints Color3", contains(source, "FillColor = Color3.fromRGB(255, 0, 0),"))
	check("Highlight prints Lifetime", contains(source, "Lifetime = 0.5,"))
	check("Highlight pulls Players", contains(source, "local Players = game:GetService"))
	check("Highlight pulls VFXService", contains(source, 'GetService("VFXService")'))
	check(
		"Highlight targets the caster",
		contains(source, 'Players:GetPlayers(), "Highlight", character.instance')
	)
end

do
	-- Два частицы на одном кадре получают разные `UUID`, иначе вторая остановила бы
	-- первую по чужому ключу.
	local result = run({
		block("v1", "EmitParticle", { Particle = "Hit" }, { StartFrame = 0 }),
		block("v2", "EmitParticle", { Particle = "Hit" }, { StartFrame = 0 }),
	})
	local source = result.Source

	check(
		"EmitParticle prints a UUID counter",
		contains(source, "local function NextUuid(): number")
	)
	check("EmitParticle numbers UUIDs", contains(source, "local ParticleUUID1 = NextUuid()"))
	check("second particle gets its own UUID", contains(source, "local ParticleUUID2 = NextUuid()"))
	check("EmitParticle uses the first uuid", contains(source, "UUID = ParticleUUID1,"))
	check("EmitParticle pulls Models", contains(source, "local Models = self.Assets.Models"))
	check("EmitParticle registers cleanup", contains(source, '"EmitParticle", ParticleUUID1)'))
end

do
	local result = run({ block("v1", "EmitParticle", {}) })
	check("EmitParticle without a model is reported", has(result.Errors, "EMIT_ASSET"))
	check(
		"EmitParticle without a model prints nothing",
		not contains(result.Source, "EmitParticle")
	)
end

do
	local result = run({ block("a1", "PlayAnimation", { Slot = "missing" }) })
	check("unknown animation slot is reported", has(result.Errors, "EMIT_SLOT"))
	check("unknown animation slot prints nothing", not contains(result.Source, "StartEffect"))
end

-- 8. СТЕЙТ, БРОНЯ, ЦЕЛИ ------------------------------------------------------

do
	-- Имя свойства едет рядом с именем параметра, потому что у блоков оно разное:
	-- `Value` у чисел и `State` у флагов. Раньше тест подставлял `Value = 3` всем
	-- пятерым, из-за чего `SetArmor` и `SetRestrain` «проходили», печатая в пустоту.
	local cases = {
		{ blockType = "SetMaxWalkSpeed", parameter = "MaxWalkSpeed", field = "Value", value = 3 },
		{ blockType = "SetMinWalkSpeed", parameter = "MinWalkSpeed", field = "Value", value = 3 },
		{ blockType = "SetMaxJumpPower", parameter = "MaxJumpPower", field = "Value", value = 3 },
		{ blockType = "SetArmor", parameter = "Armor", field = "State", value = true },
		{ blockType = "SetRagdoll", parameter = "Ragdoll", field = "State", value = true },
		{ blockType = "SetRestrain", parameter = "Restrain", field = "State", value = true },
	}

	for index, case in cases do
		local result = run({ block("s1", case.blockType, { [case.field] = case.value }) })

		check(
			`{case.blockType} sets {case.parameter}`,
			contains(result.Source, `AddParameter("{case.parameter}", {tostring(case.value)})`),
			case.parameter .. " #" .. index
		)
		check(`{case.blockType} has no errors`, #result.Errors == 0)
	end
end

do
	-- Обратная сторона: имя свойства теперь различается, поэтому блок, заполненный не
	-- тем полем, обязан ругаться, а не печатать `AddParameter(..., nil)`. Это и есть
	-- тот случай, который раньше проходил незамеченным.
	local wrongField = run({ block("s1", "SetArmor", { Value = true }) })

	check("SetArmor reports a missing State", has(wrongField.Errors, "EMIT_VALUE"))
	check(
		"SetArmor prints nothing for a missing State",
		not contains(wrongField.Source, 'AddParameter("Armor"')
	)
end

do
	local result = run({ block("s1", "SetIFrames", {}) })
	local source = result.Source

	check(
		"SetIFrames defaults to True",
		contains(source, 'AddParameter("IFrames", Enums.IFrames.True)')
	)
	check("SetIFrames pulls Enums", contains(source, "local Enums"))
end

do
	local result = run({ block("s1", "SetNoCollision", {}) })
	check(
		"SetNoCollision defaults to true",
		contains(result.Source, 'AddParameter("NoCollision", true)')
	)
end

do
	-- `Watchers.luau:68` схлопывает `false` в `true`, поэтому незаполненное поле
	-- эмитится как `true`, а не как `nil` (§2.8).
	local result = run({ block("s1", "SetDamageMultiplier", {}) })
	check("missing state value is reported", has(result.Errors, "EMIT_VALUE"))
	check("missing state value prints nothing", not contains(result.Source, "DamageMultiplier"))
end

do
	-- `AddArmor` обязан класть ручку в ИМЕНОВАННЫЙ слот: локальная переменная внутри
	-- callback'а кадра недостижима из более позднего кадра, и отменить броню посреди
	-- sequence было нечем. Именованный слот адресуем, и `RemoveArmor` его снимает.
	local result = run({ block("a1", "AddArmor") })
	local source = result.Source

	check("AddArmor has no errors", #result.Errors == 0)
	check(
		"AddArmor stores the handle in a named slot",
		contains(source, 'seq.Cleaner:Set("Armor1", CombatService:AddArmor(character))')
	)
	check("AddArmor binds no per-frame local", not contains(source, "local Armor1"))
end

do
	-- `RemoveArmor` снимает все брони дерева, а не одну: он не знает, какой из
	-- `AddArmor` в нём относится к нему.
	local result = run({
		block("a1", "AddArmor"),
		block("a2", "AddArmor"),
		block("r1", "RemoveArmor"),
	})
	local source = result.Source

	check("RemoveArmor has no errors", #result.Errors == 0)
	check("RemoveArmor clears the first slot", contains(source, 'seq.Cleaner:Remove("Armor1")'))
	check("RemoveArmor clears the second slot", contains(source, 'seq.Cleaner:Remove("Armor2")'))

	-- Ровно два `Set` и два `Remove` на два блока каждого вида: отменитель не должен
	-- ни дублировать выдачу брони, ни вычитать лишние слоты.
	check("two AddArmor produce two Set calls", count(source, 'seq.Cleaner:Set("Armor') == 2)
	check("two Remove calls in total", count(source, "seq.Cleaner:Remove") == 2)
end

do
	-- Отменитель без единого `AddArmor` не должен печатать `Remove` по воздуху: слот
	-- не существует, и строка была бы шумом в выводе без смысла.
	local result = run({ block("r1", "RemoveArmor") })

	check("RemoveArmor alone has no errors", #result.Errors == 0)
	check("RemoveArmor alone prints nothing", not contains(result.Source, "seq.Cleaner:Remove"))
end

do
	-- Отменитель, стоящий в дереве ДО создателя, всё равно знает имена: счётчик
	-- берётся из дерева заранее, а не из порядка эмиссии.
	local result = run({
		block("r1", "RemoveArmor"),
		block("a1", "AddArmor"),
	})
	local source = result.Source

	check(
		"RemoveArmor before AddArmor knows the name",
		contains(source, 'seq.Cleaner:Remove("Armor1")')
	)
end

do
	-- Вложенный броневой блок тоже занимает слот, иначе номера разъедутся.
	local result = run({
		block("a1", "ProcessAttack", nil, {
			Children = {
				OnSuccess = {
					block("a2", "AddArmor"),
				},
			},
		}),
		block("a3", "AddArmor"),
		block("r1", "RemoveArmor"),
	})
	local source = result.Source

	check("RemoveArmor counts nested AddArmor", contains(source, 'seq.Cleaner:Remove("Armor2")'))
	check("RemoveArmor counts top-level AddArmor", contains(source, 'seq.Cleaner:Remove("Armor1")'))
end

do
	-- Граб кладётся в именованный слот по той же причине, что и броня: иначе
	-- `ReleaseGrab` нечего отпускать.
	local result = run({
		block("g1", "CreateGrab", { BindMode = "None", Offset = CF() }),
		block("g2", "CreateGrab", { BindMode = "None", Offset = CF() }),
		block("r1", "ReleaseGrab"),
	})
	local source = result.Source

	check(
		"CreateGrab stores in a named slot",
		contains(source, 'seq.Cleaner:Set("Grab1", CombatService:CreateGrab')
	)
	check(
		"CreateGrab numbers its slots",
		contains(source, 'seq.Cleaner:Set("Grab2", CombatService:CreateGrab')
	)
	check("ReleaseGrab clears the first grab", contains(source, 'seq.Cleaner:Remove("Grab1")'))
	check("ReleaseGrab clears the second grab", contains(source, 'seq.Cleaner:Remove("Grab2")'))
end

do
	local result = run({ block("r1", "ReleaseGrab") })

	check("ReleaseGrab alone has no errors", #result.Errors == 0)
	check("ReleaseGrab alone prints nothing", not contains(result.Source, "seq.Cleaner:Remove"))
end

do
	-- `ReleaseGrab` не должен оборачиваться в цикл по целям: хват снимается с
	-- именованного слота, а не с `Target`, и лишний цикл был бы пустым.
	local result = run({
		block("g1", "CreateGrab", { BindMode = "None", Offset = CF() }),
		block("r1", "ReleaseGrab"),
	})
	local source = result.Source

	check(
		"ReleaseGrab takes no target loop",
		not contains(source, "for _, Target in Targets1 do\n\tseq.Cleaner:Remove")
	)
end

do
	-- `FilterTargets` удалён как лишний: `Hitbox.MaxTargets` и `Hitbox.SortByDistance`
	-- делают ту же работу, а сам блок умел только сортировать и усекать, не имея
	-- доступа к `Data`, — то есть отфильтровать цель по результату атаки он не мог.
	-- Старый blueprint с ним обязан падать понятной ошибкой, а не печатать пустоту.
	local result = run({ block("f1", "FilterTargets", { MaxTargets = "All" }) })

	check("FilterTargets is no longer a block type", has(result.Errors, "EMIT_BLOCK"))
	check("FilterTargets prints nothing", not contains(result.Source, "FilterTargets"))
end

do
	local result = run({ block("c1", "ClearTargets") })
	check("ClearTargets empties the list", contains(result.Source, "seq.Ctx.Targets = {}"))
	check("ClearTargets has no errors", #result.Errors == 0)
end

do
	local result = run({
		block(
			"h1",
			"Hitbox",
			{ Size = V3(7, 7, 7), Offset = CF(0, 0, -3), MaxTargets = "Nearest" }
		),
	})
	local source = result.Source

	check(
		"Hitbox has no errors",
		#result.Errors == 0,
		result.Errors[1] and result.Errors[1].Message
	)
	check("Hitbox passes Skill", contains(source, "Skill = self,"))
	check("Hitbox passes Caster", contains(source, "Caster = character,"))
	check("Hitbox prints Vector3", contains(source, "Size = Vector3.new(7, 7, 7),"))
	check("Hitbox does not print Shape", not contains(source, "Shape"))
	check("Hitbox prints no Shape even when set", not contains(source, "Shape ="))
	check("Hitbox prints CFrame", contains(source, "Offset = CFrame.new(0, 0, -3),"))
	check("Hitbox skips the identity Origin", not contains(source, "Origin = CFrame.new(0, 0, 0),"))
	check("Hitbox trims to one nearest hit", contains(source, "if #Hit1 >= 1 then break end"))
	check("Hitbox forces SortByDistance for Nearest", contains(source, "SortByDistance = true"))
	check("Hitbox writes targets to Ctx", contains(source, "seq.Ctx.Targets = Hit1"))
end
do
	-- Сфера: `Size` числом — это РАДИУС, и `CombatService:Hitbox:96` сам выбирает по
	-- типу `GetPartBoundsInRadius`. Отдельного поля `Shape` в `Info` нет и печатать его
	-- нельзя: сервис его не читает, и файл лишь утверждал бы, что форма задана явно.
	local result = run({ block("h1", "Hitbox", { Shape = "Ball", Size = 6 }) })
	local source = result.Source

	check("Ball hitbox has no errors", #result.Errors == 0)
	check("Ball hitbox prints a numeric radius", contains(source, "Size = 6,"))
	check("Ball hitbox prints no Vector3", not contains(source, "Size = Vector3"))
	check("Ball hitbox prints no Shape key", not contains(source, "Shape"))
end

do
	-- `Ball` с векторным `Size` обязан быть отвергнут, а не тихо напечатан: получился
	-- бы куб при заявленной сфере. Эмиттер проверяет это сам, потому что его можно
	-- вызвать напрямую, минуя валидатор, — как это делает `PreviewTab`.
	local result = run({ block("h1", "Hitbox", { Shape = "Ball", Size = V3(7, 7, 7) }) })
	local source = result.Source

	check("Ball with a Vector3 reports EMIT_VALUE", has(result.Errors, "EMIT_VALUE"))
	check("Ball with a Vector3 prints no Size", not contains(source, "Size ="))
end

do
	-- Обратная сторона: `Box` с числом. Без проверки это был бы шар там, где обещан
	-- куб, — и размер «7» означал бы поперечник вместо стороны.
	local result = run({ block("h1", "Hitbox", { Shape = "Box", Size = 7 }) })

	check("Box with a numeric Size reports EMIT_VALUE", has(result.Errors, "EMIT_VALUE"))
	check("Box with a numeric Size prints no Size", not contains(result.Source, "Size ="))
end

do
	-- Файл версии 1 не знает про `Shape` и хранит только `Size`. Он обязан остаться
	-- рабочим: без `Shape` форма выводится из типа `Size` ровно как раньше.
	local vectorLegacy = run({ block("h1", "Hitbox", { Size = V3(7, 7, 7) }) })
	local ballLegacy = run({ block("h1", "Hitbox", { Size = 6 }) })

	check("legacy Vector3 Size has no errors", #vectorLegacy.Errors == 0)
	check("legacy numeric Size has no errors", #ballLegacy.Errors == 0)
	check("legacy numeric Size prints as a number", contains(ballLegacy.Source, "Size = 6,"))
	check(
		"legacy Vector3 Size prints as a Vector3",
		contains(vectorLegacy.Source, "Size = Vector3.new(7, 7, 7),")
	)
end

do
	-- Код вставляется как есть, но без внешних отступов и без пустых строк по краям:
	-- иначе он съехал бы относительно тела callback.
	local result = run({ block("k1", "CustomCallback", { Code = "\n\tprint(1)\n\n\tprint(2)\n" }) })
	local source = result.Source

	check(
		"CustomCallback inserts code verbatim",
		contains(source, "\t\t\t\t\tprint(1)\n\n\t\t\t\t\tprint(2)")
	)
	check("CustomCallback drops surrounding blank lines", not contains(source, "print(2)\n\n"))
	check("CustomCallback has no errors", #result.Errors == 0)
end

do
	local result = run({ block("x1", "NoSuchBlock") })
	check("unknown block type is reported", has(result.Errors, "EMIT_BLOCK"))
	check("unknown block type still returns a source", contains(result.Source, "return Skill"))
end

-- 9. ASSETS И STAND ----------------------------------------------------------

do
	local result = run({ block("v1", "PlaySound", { Sound = "Hit" }) }, { AssetSource = "Stand" })
	local source = result.Source

	check("Stand pulls StandService", contains(source, 'GetService("StandService")'))
	check("Stand resolves the stand", contains(source, "StandService:GetStand(self.Character)"))
	check(
		"Stand switches assets",
		contains(source, "self.Spec.Data.Assets.Stand or self.Spec.Data.Assets")
	)
end

do
	local result = run({ block("v1", "PlaySound", { Sound = "Hit" }) })
	check(
		"Spec assets take the plain path",
		contains(result.Source, "self.Assets = self.Spec.Data.Assets")
	)
end

-- 10. PREVIEW ---------------------------------------------------------------

do
	local result = run({
		block("w1", "Wait", nil, { StartFrame = 90 }),
		block("r1", "Repeat", nil, {
			StartFrame = 10,
			EndFrame = 40,
			Children = { Body = { block("c1", "SetMaxWalkSpeed", { Value = 8 }) } },
		}),
		block("p1", "ProcessAttack", { Damage = 1 }, { StartFrame = 20 }),
	})

	check("preview has no errors", #result.Errors == 0)
	check("preview has three entries", #result.Preview == 3, tostring(#result.Preview))
	check("preview marks ranges", result.Preview[1].Kind == "Range")
	check(
		"preview keeps the range end",
		result.Preview[1].EndFrame == 40,
		tostring(result.Preview[1].EndFrame)
	)
	check("preview marks singles", result.Preview[2].Kind == "Single")

	local frames: { number } = {}
	for _, item in result.Preview do
		table.insert(frames, item.Frame)
		check("preview never exposes the terminator", item.Kind ~= "Terminator")
	end
	check(
		"preview follows the frames order",
		frames[1] == 10 and frames[2] == 20 and frames[3] == 90
	)

	local range = result.Preview[1]
	check("preview lists nested blocks", #range.Blocks == 2, tostring(#range.Blocks))
	check("preview block carries Id", range.Blocks[1].Id == "r1")
	check("preview block carries Type", range.Blocks[2].Type == "SetMaxWalkSpeed")
	check("preview block carries a label", range.Blocks[2].Label == "SetMaxWalkSpeed")

	local wait = result.Preview[3]
	check("Wait stays visible in preview", #wait.Blocks == 1 and wait.Blocks[1].Type == "Wait")

	local attack = result.Preview[2]
	check("preview omits the preamble frame", attack.Frame == 20)
	check("preview marks the attack frame", previewFrameAt(result, 20) == attack)

	local only =
		previewOf(codec.encode(blueprint({ block("w1", "Wait", nil, { StartFrame = 30 }) })))
	check("preview helper matches emit", #only == 1 and only[1].Frame == 30)
end

-- 11. ЖИВУЧЕСТЬ --------------------------------------------------------------

do
	local result = emit("not a table")
	check("non-table input is reported", #result.Errors == 1)
	check("non-table input has a code", result.Errors[1].Code == "EMIT_INPUT")
	check("non-table input has an empty source", result.Source == "")
	check("non-table input has an empty preview", #result.Preview == 0)
end

do
	local result = run({
		block("b1", "ProcessAttack", { Stun = "not a table" }, { StartFrame = "not a number" }),
	})
	check("garbage properties do not crash", #result.Source > 0)
	check("garbage StartFrame is reported", has(result.Errors, "EMIT_FRAME"))
	check("garbage properties are reported", has(result.Errors, "EMIT_VALUE"))
	check("garbage preview stays a list", type(result.Preview) == "table")
	check("empty Info prints inline", contains(result.Source, "Info = {},"))
end

do
	local result =
		run({ block("v1", "EmitParticle", { Particle = "Hit", Offset = { ["$"] = "NOPE" } }) })
	check("unknown type tag is reported", has(result.Errors, "EMIT_VALUE"))
	check("unknown type tag prints nothing", not contains(result.Source, "NOPE"))
end

do
	-- Эмиттер не имеет права ломать вход: `__slots` — служебное поле, и в JSON оно
	-- не должно просочиться обратно.
	local json = codec.encode(blueprint({
		block("r1", "Repeat", nil, {
			StartFrame = 0,
			EndFrame = 10,
			Children = { Body = { block("c1", "SetMaxWalkSpeed", { Value = 8 }) } },
		}),
	}))
	emit(json)

	check("input blueprint is not mutated", json.Blocks[1].__slots == nil)
	check("input children stay plain", json.Blocks[1].Children ~= nil)
end

-- 12. СИНТАКСИС В STUDIO ----------------------------------------------------

do
	-- В Studio исходник можно отдать компилятору: сгенерированный модуль обязан
	-- разбираться, иначе ошибка уезжает пользователю вместе с экспортом.
	local source = run({
		block(
			"h1",
			"Hitbox",
			{ Size = V3(7, 7, 7), Origin = CF(1, 2, 3, 0, 90, 0) },
			{ StartFrame = 0 }
		),
		block(
			"p1",
			"ProcessAttack",
			{ Damage = 15, Stun = { Duration = 0.7, Priority = "Medium" } },
			{
				StartFrame = 10,
				Children = {
					OnSuccess = {
						block("v1", "EmitParticle", { Particle = "Hit", Origin = "Target" }),
					},
				},
			}
		),
		block("r1", "Repeat", nil, {
			StartFrame = 20,
			EndFrame = 40,
			Children = { Body = { block("a1", "AddArmor") } },
		}),
	}, {
		AssetSource = "Stand",
		AnimationSlots = { { Id = "a1", AnimationId = "Punch" } },
	})

	check(
		"complex skill has no errors",
		#source.Errors == 0,
		source.Errors[1] and source.Errors[1].Message
	)
	check(
		"complex skill prints rotated CFrame",
		contains(source.Source, "CFrame.fromEulerAnglesYXZ")
	)
	check(
		"complex skill keeps the Stun group",
		contains(source.Source, "Priority = Enums.Stun.Medium,")
	)

	if loadstring ~= nil then
		local ok, err = pcall(loadstring, source.Source, "GeneratedSkill")
		check("generated source parses", ok, if ok then nil else tostring(err))
	end
end

-- 13. ДОСТУП ДЛЯ UI -----------------------------------------------------------

do
	-- `maxFrame` и `framesSource` вынесены из `emit` для UI: таймлайн и футер берут
	-- итоговый кадр отсюда, а не пересчитывают его своей формулой. Расхождение
	-- с модулем уехало бы в экспортированный файл незаметно для пользователя.

	local empty = codec.encode(blueprint({}))
	check("empty skill keeps the frame floor", emitter.maxFrame(empty) == emitter.MIN_FRAMES)

	local late = codec.encode(blueprint({ block("w1", "Wait", nil, { StartFrame = 90 }) }))
	check("max frame follows the last block", emitter.maxFrame(late) == 90)

	-- Пол 60 не даёт проверить короткий диапазон: `EndFrame = 45` всё равно дал бы
	-- 60, поэтому верхняя граница берётся заведомо выше пола.
	local ranged = codec.encode(blueprint({
		block("r1", "Repeat", nil, {
			StartFrame = 10,
			EndFrame = 95,
			Children = { Body = { block("a1", "AddArmor") } },
		}),
	}))
	check("max frame follows Repeat.EndFrame", emitter.maxFrame(ranged) == 95)

	local nested = codec.encode(blueprint({
		block("r1", "Repeat", nil, {
			StartFrame = 0,
			EndFrame = 30,
			Children = { Body = { block("w1", "Wait", nil, { StartFrame = 70 }) } },
		}),
	}))
	check("max frame counts nested blocks", emitter.maxFrame(nested) == 70)

	local json = codec.encode(blueprint({
		block("h1", "Hitbox", { Size = V3(7, 7, 7), Origin = CF(1, 2, 3) }, { StartFrame = 5 }),
	}))
	local frames = emitter.framesSource(json)

	check("frames source is a part of the module", contains(emit(json).Source, frames))
	check("frames source opens with Frames", contains(frames, "Frames = {"))
	check("frames source closes the table", string.sub(frames, -1) == "}")

	if loadstring ~= nil then
		local ok, err = pcall(loadstring, `return function()\n{frames}\nend`, "GeneratedFrames")
		check("frames source parses standalone", ok, if ok then nil else tostring(err))
	end
end

print(`[SkillConstructor.tests.emitter] passed: {passed}, failed: {#failures}`)

if #failures > 0 then error(table.concat(failures, "\n"), 0) end

return { passed = passed, failed = #failures }
