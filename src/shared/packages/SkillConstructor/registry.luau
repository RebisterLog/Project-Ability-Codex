--- Каталог блоков конструктора скиллов (docs/SKILL_CONSTRUCTOR_TASK.md, §5).
---
--- Модуль — чистые данные: он ничего не `require`-ит, не обращается к Roblox-глобалам
--- и не конструирует Roblox-типы, чтобы его можно было грузить и в игре, и в `lune`
--- (§3, критерии 2 и 12). Отсюда два следствия:
---
--- * типы не импортируются — `lune` не умеет разбирать `type X = require(...)`,
---   поэтому канонические определения лежат в `types.luau`, а типизированный фасад
---   для игрового кода собирает `init.luau`;
--- * `Color` — это HEX-строка, а значения `Vector3` / `CFrame` / `Color3` хранятся
---   в виде type-tag из `codec` (§8): `{ ["$"] = "V3", x = 0, y = 0, z = 0 }`.
---   Конвертация в Roblox-типы происходит только в UI и в эмиттере.
---
--- Description — единственная пользовательская строка в модуле, поэтому он английский,
--- как и весь текст, который видит игрок; комментарии для разработчика остаются русскими.
---
--- Дефолты берутся из проверенных источников (§5, §15), а не выдуманы: ссылка на
--- конкретную строку дана в комментарии у свойства там, где дефолт неочевиден.

--- Категории в порядке отображения в палитре.
local CATEGORY_ORDER = {
	"Query",
	"Damage",
	"State",
	"Combat",
	"VFX",
	"Flow",
	"Target",
}

--- HEX-цвета категорий (§10). Конвертируются в `Color3` в UI.
local CATEGORY_COLORS = {
	Query = "#4FC3F7",
	Damage = "#EF5350",
	State = "#FFA726",
	Combat = "#AB47BC",
	VFX = "#EC407A",
	Flow = "#78909C",
	Target = "#26A69A",
}

--- Значения `Enums.IFrames` (src/server/Enums.luau:2-7). Хранятся именами, а не числами:
--- blueprint переживает добавление новых значений в `Enums` (§8).
local IFRAME_LEVELS = { "Ragdoll", "Dodge", "Grab", "True" }

--- Значения `Enums.Stun` (src/server/Enums.luau:9-14).
local STUN_PRIORITIES = { "None", "Light", "Medium", "Heavy" }

--- Скрытые дефолты секции `Block` (CombatService/Hooks/Block.luau:24-29).
--- Реестр их не применяет — UI показывает их как «эффективные» значения для
--- незаполненных полей, чтобы скрытое поведение было видно (§10).
local DEFAULT_BLOCK = {
	Blockable = true,
	PerfectBlockable = true,
	BlockBreak = false,
	BlockCancel = false,
	BlockIgnore = false,
}

local function V3(x: number, y: number, z: number)
	return { ["$"] = "V3", x = x, y = y, z = z }
end

local function CF(px: number?, py: number?, pz: number?, rx: number?, ry: number?, rz: number?)
	return {
		["$"] = "CF",
		px = px or 0,
		py = py or 0,
		pz = pz or 0,
		rx = rx or 0,
		ry = ry or 0,
		rz = rz or 0,
	}
end

local function C3(r: number, g: number, b: number)
	return { ["$"] = "C3", r = r, g = g, b = b }
end

--- Слоты реакций `ProcessAttack`. Условия статические и известны на этапе генерации,
--- пустые слоты не эмитятся (§5, §7). `OnIFrames` исключён: `Hooks/IFrames.luau:19`
--- обнуляет `State.IFrames`, то есть задетектировать его невозможно (§2.6).
local ATTACK_SLOTS = {
	"OnSuccess",
	"OnBlocked",
	"OnBlockBroken",
	"OnBlockCanceled",
	"OnPerfectBlocked",
	"OnArmored",
	"OnRagdolled",
} :: { string }

local BLOCKS = {
	-- QUERY ---------------------------------------------------------------

	Hitbox = {
		Id = "Hitbox",
		DisplayName = "Hitbox",
		Category = "Query",
		Color = CATEGORY_COLORS.Query,
		Description = "Queries characters inside the hitbox and stores them in seq.Ctx.Targets",
		Cleanup = "None",
		Properties = {
			{
				Name = "Size",
				Type = { "Vector3", "number" },
				Default = V3(7, 7, 7),
				Step = 0.5,
			},
			{
				-- Базовая CFrame хита относительно RootPart кастера; Offset
				-- применяется поверх неё. Обязательна: Bot.luau читает Info.Origin
				-- и без него считает хитбокс в другой точке (2.9).
				Name = "Origin",
				Type = "CFrame",
				Default = CF(),
				Required = true,
			},
			{
				Name = "Offset",
				Type = "CFrame",
				Default = CF(0, 0, -3),
			},
			{ Name = "SortByDistance", Type = "boolean", Default = true },
			{
				-- В HitboxData.Info такого поля нет, поэтому эмиттер обязан
				-- обрезать выдачу сам, сразу после вызова CombatService:Hitbox.
				Name = "MaxTargets",
				Type = "number",
				Default = 1,
				Min = 1,
				Max = 64,
				Step = 1,
			},
			{ Name = "CanQueryCaster", Type = "boolean", Default = false },
			{ Name = "MovementCorrection", Type = "boolean", Default = true },
			{ Name = "Debug", Type = "boolean", Default = true },
		},
	},

	-- DAMAGE --------------------------------------------------------------

	ProcessAttack = {
		Id = "ProcessAttack",
		DisplayName = "Process Attack",
		Category = "Damage",
		Color = CATEGORY_COLORS.Damage,
		Description = "One CombatService:Attack call per target from seq.Ctx.Targets",
		Cleanup = "None",
		ChildrenSlots = ATTACK_SLOTS,
		RequiredSlots = { "OnSuccess" },
		Properties = {
			{
				-- IFrames-хуки пропускают удар, только если уровень IFrames цели
				-- не выше приоритета атаки (Hooks/IFrames.luau:15-20).
				Name = "Priority",
				Type = "number",
				Default = 0,
				Min = 0,
				Max = 10000,
				Step = 1,
			},
			{ Name = "Damage", Type = "number", Default = 15, Min = 0, Step = 0.5 },
			{
				Name = "Stun.Duration",
				Type = "number",
				Default = 0.7,
				Min = 0,
				Step = 0.05,
				Group = "Stun",
			},
			{
				Name = "Stun.Priority",
				Type = "enum",
				Options = STUN_PRIORITIES,
				Default = "Medium",
				Group = "Stun",
			},
			{
				-- Частичная секция разрешена: у неё есть скрытые дефолты (§2.7).
				-- Пока поле не задано, UI показывает эффективное значение серым.
				Name = "Block.Blockable",
				Type = "boolean",
				Default = nil,
				Group = "Block",
			},
			{
				Name = "Block.PerfectBlockable",
				Type = "boolean",
				Default = nil,
				Group = "Block",
			},
			{
				Name = "Block.BlockBreak",
				Type = "boolean",
				Default = nil,
				Group = "Block",
			},
			{
				Name = "Block.BlockCancel",
				Type = "boolean",
				Default = nil,
				Group = "Block",
			},
			{
				Name = "Block.BlockIgnore",
				Type = "boolean",
				Default = nil,
				Group = "Block",
			},
			{
				Name = "Knockback.RelativePart",
				Type = "enum",
				Options = { "Attacker", "Target" },
				Default = "Attacker",
				Group = "Knockback",
			},
			{
				Name = "Knockback.RelativeTowards",
				Type = "enum",
				Options = { "Attacker", "Target" },
				Default = nil,
				Group = "Knockback",
			},
			{
				Name = "Knockback.LookVector",
				Type = "Vector3",
				Default = V3(0, 0, 0),
				Group = "Knockback",
			},
			{
				Name = "Knockback.Origin",
				Type = "CFrame",
				Default = CF(),
				Group = "Knockback",
			},
			{
				-- Не bool, а дистанция: Hooks/Knockback.luau:48 прибавляет её
				-- к LookVector, чтобы доводить цель до нужной точки.
				Name = "Knockback.ToFront",
				Type = "number",
				Default = nil,
				Min = -32,
				Max = 32,
				Step = 0.5,
				Group = "Knockback",
			},
			{
				Name = "Knockback.Speed",
				Type = "number",
				Default = 40,
				Min = 0,
				Step = 1,
				Group = "Knockback",
			},
			{
				Name = "Knockback.Duration",
				Type = "number",
				Default = 0.1,
				Min = 0,
				Step = 0.05,
				Group = "Knockback",
			},
			{
				Name = "Knockback.Velocity",
				Type = "Vector3",
				Default = V3(0, 50, 0),
				Group = "Knockback",
			},
			{
				Name = "Knockback.MaxForce",
				Type = "Vector3",
				Default = V3(100000, 100000, 100000),
				Group = "Knockback",
			},
			{
				Name = "Angular.Velocity",
				Type = "Vector3",
				Default = V3(0, 0, 0),
				Group = "Angular",
			},
			{
				Name = "Angular.Speed",
				Type = "number",
				Default = 1,
				Min = 0,
				Step = 0.1,
				Group = "Angular",
			},
			{
				Name = "Angular.Duration",
				Type = "number",
				Default = 0.1,
				Min = 0,
				Step = 0.05,
				Group = "Angular",
			},
			{
				Name = "Angular.MaxTorque",
				Type = "number",
				Default = 1000000,
				Min = 0,
				Step = 1000,
				Group = "Angular",
			},
			{
				Name = "Ragdoll.Duration",
				Type = "number",
				Default = 1,
				Min = 0,
				Step = 0.1,
				Group = "Ragdoll",
			},
		},
	},

	-- STATE ---------------------------------------------------------------

	SetIFrames = {
		Id = "SetIFrames",
		DisplayName = "Set IFrames",
		Category = "State",
		Color = CATEGORY_COLORS.State,
		Description = "Grants an invulnerability level through the IFrames parameter",
		Cleanup = "Parameter",
		Properties = {
			{
				-- Это уровень, а не длительность: он сравнивается с Info.Priority
				-- в Hooks/IFrames.luau:17.
				Name = "Level",
				Type = "enum",
				Options = IFRAME_LEVELS,
				Default = "True",
			},
		},
	},

	SetDamageMultiplier = {
		Id = "SetDamageMultiplier",
		DisplayName = "Set Damage Multiplier",
		Category = "State",
		Color = CATEGORY_COLORS.State,
		Description = "Multiplier for damage dealt by the character (Hooks/Damage.luau:16)",
		Cleanup = "Parameter",
		Properties = {
			{ Name = "Value", Type = "number", Default = 1, Min = 0, Step = 0.05 },
		},
	},

	SetDamageReceivalMultiplier = {
		Id = "SetDamageReceivalMultiplier",
		DisplayName = "Set Damage Receival Multiplier",
		Category = "State",
		Color = CATEGORY_COLORS.State,
		Description = "Multiplier for damage received by the character (Hooks/Damage.luau:17)",
		Cleanup = "Parameter",
		Properties = {
			{ Name = "Value", Type = "number", Default = 1, Min = 0, Step = 0.05 },
		},
	},

	SetMaxWalkSpeed = {
		Id = "SetMaxWalkSpeed",
		DisplayName = "Set Max Walk Speed",
		Category = "State",
		Color = CATEGORY_COLORS.State,
		Description = "Upper bound of the walk speed",
		Cleanup = "Parameter",
		Properties = {
			{ Name = "Value", Type = "number", Default = 16, Min = 0, Step = 1 },
		},
	},

	SetMinWalkSpeed = {
		Id = "SetMinWalkSpeed",
		DisplayName = "Set Min Walk Speed",
		Category = "State",
		Color = CATEGORY_COLORS.State,
		Description = "Lower bound of the walk speed",
		Cleanup = "Parameter",
		Properties = {
			{ Name = "Value", Type = "number", Default = 0, Min = 0, Step = 1 },
		},
	},

	SetMaxJumpPower = {
		Id = "SetMaxJumpPower",
		DisplayName = "Set Max Jump Power",
		Category = "State",
		Color = CATEGORY_COLORS.State,
		Description = "Jump ceiling. Watchers.luau:25 additionally clamps it to 50",
		Cleanup = "Parameter",
		Properties = {
			{ Name = "Value", Type = "number", Default = 0, Min = 0, Max = 50, Step = 1 },
		},
	},

	SetArmor = {
		Id = "SetArmor",
		DisplayName = "Set Armor",
		Category = "State",
		Color = CATEGORY_COLORS.State,
		Description = "Enables armor: damage lands and the target is not knocked into ragdoll",
		Cleanup = "Parameter",
		Properties = {
			{ Name = "State", Type = "boolean", Default = true },
		},
	},

	SetRagdoll = {
		Id = "SetRagdoll",
		DisplayName = "Set Ragdoll",
		Category = "State",
		Color = CATEGORY_COLORS.State,
		Description = "Goes limp. Comes with IFrames.Ragdoll",
		Cleanup = "Parameter",
		Properties = {
			{ Name = "State", Type = "boolean", Default = true },
		},
	},

	SetNoCollision = {
		Id = "SetNoCollision",
		DisplayName = "Set No Collision",
		Category = "State",
		Color = CATEGORY_COLORS.State,
		Description = "Disables collision with players. Only accepts true",
		Cleanup = "Parameter",
		Properties = {
			{
				-- Watchers.luau:68 схлопывает `false` в `true`, поэтому валидатор
				-- отклоняет `false` (§2.8, проверка 17).
				Name = "State",
				Type = "boolean",
				Default = true,
			},
		},
	},

	SetRestrain = {
		Id = "SetRestrain",
		DisplayName = "Set Restrain",
		Category = "State",
		Color = CATEGORY_COLORS.State,
		Description = "Disables auto rotate and zeroes walk speed and jump power",
		Cleanup = "Parameter",
		Properties = {
			{ Name = "State", Type = "boolean", Default = true },
		},
	},

	-- COMBAT --------------------------------------------------------------

	AddArmor = {
		Id = "AddArmor",
		DisplayName = "Add Armor",
		Category = "Combat",
		Color = CATEGORY_COLORS.Combat,
		Description = "Grants armor together with a highlight. Returns Crane.Janitor",
		Cleanup = "Janitor",
		Properties = {},
	},

	CreateGrab = {
		Id = "CreateGrab",
		DisplayName = "Create Grab",
		Category = "Combat",
		Color = CATEGORY_COLORS.Combat,
		Description = "Grabs the target: IFrames for both, collision off and binding",
		Cleanup = "Object",
		Properties = {
			{
				-- CreateGrab.luau:229 — restraint включается, если поле не равно `false`,
				-- поэтому изначально оно не задано и срабатывает как `true`.
				Name = "AttackerRestrain",
				Type = "boolean",
				Default = true,
			},
			{
				Name = "VictimRestrain",
				Type = "boolean",
				Default = true,
			},
			{
				Name = "BindMode",
				Type = "enum",
				Options = { "None", "RootToRoot" },
				Default = "RootToRoot",
			},
			{
				Name = "Offset",
				Type = "CFrame",
				Default = CF(0, 0, -4),
			},
		},
	},

	-- VFX -----------------------------------------------------------------

	PlayAnimation = {
		Id = "PlayAnimation",
		DisplayName = "Play Animation",
		Category = "VFX",
		Color = CATEGORY_COLORS.VFX,
		Description = "Plays the animation of a slot, referenced by its Id",
		Cleanup = "VFXStop",
		Properties = {
			{ Name = "Slot", Type = "string", Default = nil, Required = true },
			{
				-- Не задано — берётся скорость слота, а если и её нет, то
				-- скорость sequence.
				Name = "Speed",
				Type = "number",
				Default = nil,
				Min = 0,
				Step = 0.05,
			},
		},
	},

	StopAnimation = {
		Id = "StopAnimation",
		DisplayName = "Stop Animation",
		Category = "VFX",
		Color = CATEGORY_COLORS.VFX,
		Description = "Stops the animation of a slot with a fade out",
		Cleanup = "None",
		Properties = {
			{ Name = "Slot", Type = "string", Default = nil, Required = true },
			{
				Name = "FadeTime",
				Type = "number",
				Default = 0.3,
				Min = 0,
				Step = 0.05,
			},
		},
	},

	PlaySound = {
		Id = "PlaySound",
		DisplayName = "Play Sound",
		Category = "VFX",
		Color = CATEGORY_COLORS.VFX,
		Description = "Plays a sound from Assets.Sounds at RootPart",
		Cleanup = "VFXStop",
		Properties = {
			{ Name = "Sound", Type = "string", Default = nil, Required = true },
			{ Name = "Volume", Type = "number", Default = 1, Min = 0, Max = 1, Step = 0.05 },
			{ Name = "MaxDistance", Type = "number", Default = 100, Min = 1, Step = 1 },
			{ Name = "MinDistance", Type = "number", Default = 10, Min = 0, Step = 1 },
		},
	},

	EmitParticle = {
		Id = "EmitParticle",
		DisplayName = "Emit Particle",
		Category = "VFX",
		Color = CATEGORY_COLORS.VFX,
		Description = "Emits a particle model from Assets.Models",
		Cleanup = "VFXStop",
		Properties = {
			{ Name = "Particle", Type = "string", Default = nil, Required = true },
			{
				-- Базовая CFrame хита относительно RootPart кастера; Offset
				-- применяется поверх неё. Обязательна: Bot.luau читает Info.Origin
				-- и без него считает хитбокс в другой точке (2.9).
				Name = "Origin",
				Type = "enum",
				Options = { "Caster", "Target" },
				Default = "Caster",
			},
			{ Name = "Offset", Type = "CFrame", Default = CF() },
			{ Name = "UseForge", Type = "boolean", Default = false },
		},
	},

	EmitFolder = {
		Id = "EmitFolder",
		DisplayName = "Emit Folder",
		Category = "VFX",
		Color = CATEGORY_COLORS.VFX,
		Description = "Distributes effects from a folder across the body parts of the character",
		Cleanup = "VFXStop",
		Properties = {
			{ Name = "Folder", Type = "string", Default = nil, Required = true },
			{
				-- Базовая CFrame хита относительно RootPart кастера; Offset
				-- применяется поверх неё. Обязательна: Bot.luau читает Info.Origin
				-- и без него считает хитбокс в другой точке (2.9).
				Name = "Origin",
				Type = "enum",
				Options = { "Caster", "Target" },
				Default = "Caster",
			},
		},
	},

	Highlight = {
		Id = "Highlight",
		DisplayName = "Highlight",
		Category = "VFX",
		Color = CATEGORY_COLORS.VFX,
		Description = "Highlights the character with the given colors",
		-- `None`, а не `VFXStop`: `effects/Highlight.luau:53-55` кладёт Highlight
		-- в кэш только в ветке `elseif Data.UUID`, а `Lifetime` обязателен и
		-- срабатывает раньше — `onStop` по UUID не найдёт ничего. Срок жизни
		-- и так снимает подсветку (`:44-46`).
		Cleanup = "None",
		Properties = {
			{ Name = "FillColor", Type = "Color3", Default = C3(1, 0, 0) },
			{ Name = "OutlineColor", Type = "Color3", Default = C3(1, 1, 1) },
			{
				Name = "FillTransparency",
				Type = "number",
				Default = 0.5,
				Min = 0,
				Max = 1,
				Step = 0.05,
			},
			{
				Name = "OutlineTransparency",
				Type = "number",
				Default = 0,
				Min = 0,
				Max = 1,
				Step = 0.05,
			},
			{
				-- Без срока жизни Highlight остаётся висеть на персонаже
				-- (effects/Highlight.luau:44-58).
				Name = "Lifetime",
				Type = "number",
				Default = 0.5,
				Min = 0,
				Step = 0.05,
				Required = true,
			},
		},
	},

	-- FLOW ----------------------------------------------------------------

	Wait = {
		Id = "Wait",
		DisplayName = "Wait",
		Category = "Flow",
		Color = CATEGORY_COLORS.Flow,
		Description = "End of sequence marker. Never emitted, only moves maxFrame",
		Cleanup = "None",
		Properties = {},
	},

	Repeat = {
		Id = "Repeat",
		DisplayName = "Repeat",
		Category = "Flow",
		Color = CATEGORY_COLORS.Flow,
		Description = "Runs its body on every frame of the range. Bounds come from StartFrame and EndFrame",
		Cleanup = "None",
		ChildrenSlots = { "Body" },
		RequiredSlots = { "Body" },
		Properties = {},
	},

	Branch = {
		Id = "Branch",
		DisplayName = "Branch",
		Category = "Flow",
		Color = CATEGORY_COLORS.Flow,
		Description = "Picks a branch by a raw Luau condition",
		Cleanup = "None",
		ChildrenSlots = { "True", "False" },
		Properties = {
			{
				-- Попадает в сгенерированный файл дословно: осознанный escape hatch,
				-- поэтому такие блоки помечаются предупреждением W5.
				Name = "Condition",
				Type = "string",
				Default = nil,
				Required = true,
			},
		},
	},

	CustomCallback = {
		Id = "CustomCallback",
		DisplayName = "Custom Callback",
		Category = "Flow",
		Color = CATEGORY_COLORS.Flow,
		Description = "Injects raw Luau into the callback body. Flagged with warning W5",
		Cleanup = "None",
		Properties = {
			{
				Name = "Code",
				Type = "string",
				Default = nil,
				Required = true,
			},
		},
	},

	-- TARGET --------------------------------------------------------------

	FilterTargets = {
		Id = "FilterTargets",
		DisplayName = "Filter Targets",
		Category = "Target",
		Color = CATEGORY_COLORS.Target,
		Description = "Trims seq.Ctx.Targets in place and returns nothing",
		Cleanup = "None",
		Properties = {
			{ Name = "MaxTargets", Type = "number", Default = 1, Min = 1, Max = 64, Step = 1 },
			{ Name = "SortByDistance", Type = "boolean", Default = true },
		},
	},

	ClearTargets = {
		Id = "ClearTargets",
		DisplayName = "Clear Targets",
		Category = "Target",
		Color = CATEGORY_COLORS.Target,
		Description = "Empties seq.Ctx.Targets",
		Cleanup = "None",
		Properties = {},
	},
}

--- Проверка самого каталога: enum без `Options` — это ошибка разработчика, а не
--- пользователя, поэтому ловится на загрузке модуля, а не в валидаторе blueprint.
for _, definition in BLOCKS do
	for _, property in definition.Properties do
		if property.Type == "enum" and not property.Options then
			error(`[SkillConstructor] нет Options у {definition.Id}.{property.Name}`)
		end
	end
end

--- Блок по `Type`. Возвращает `nil`, если тип неизвестен — это проверка 6 в валидаторе.
local function get(id: string)
	return BLOCKS[id]
end

local function has(id: string): boolean
	return BLOCKS[id] ~= nil
end

--- Отсортированный по `CATEGORY_ORDER` список блоков категории.
local function getByCategory(category: string)
	local result = {}

	for _, definition in BLOCKS do
		if definition.Category == category then table.insert(result, definition) end
	end

	table.sort(result, function(a, b)
		return a.DisplayName < b.DisplayName
	end)

	return result
end

--- Разрешает вложенность: пустой массив значит, что блок контейнер, но слотов в нём нет.
local function getSlots(id: string)
	local definition = BLOCKS[id]
	if not definition or not definition.ChildrenSlots then return {} end
	return definition.ChildrenSlots
end

--- Свойство по плоскому имени, включая путь группы (`Stun.Duration`).
local function getProperty(id: string, name: string)
	local definition = BLOCKS[id]
	if not definition then return nil end

	for _, property in definition.Properties do
		if property.Name == name then return property end
	end

	return nil
end

--- Свойства одной группы секции. Секция `Block` не пустая никогда: она всегда
--- показывается в UI, потому что скрытые дефолты нужно сделать видимыми (§10).
local function getGroup(id: string, group: string)
	local result = {}

	local definition = BLOCKS[id]
	if not definition then return result end

	for _, property in definition.Properties do
		if property.Group == group then table.insert(result, property) end
	end

	return result
end

--- Имена групп секций блока в порядке объявления, без повторов.
local function getGroups(id: string): { string }
	local result: { string } = {}
	local seen: { [string]: boolean } = {}

	local definition = BLOCKS[id]
	if not definition then return result end

	for _, property in definition.Properties do
		local group = property.Group
		if group and not seen[group] then
			seen[group] = true
			table.insert(result, group)
		end
	end

	return result
end

return {
	CATEGORY_ORDER = CATEGORY_ORDER,
	CATEGORY_COLORS = CATEGORY_COLORS,
	DEFAULT_BLOCK = DEFAULT_BLOCK,
	BLOCKS = BLOCKS,

	get = get,
	has = has,
	getByCategory = getByCategory,
	getSlots = getSlots,
	getProperty = getProperty,
	getGroup = getGroup,
	getGroups = getGroups,
}
