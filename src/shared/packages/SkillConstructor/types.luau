--!strict

--- Типы конструктора скиллов PAC (docs/SKILL_CONSTRUCTOR_TASK.md, §4).
---
--- Модуль ничего не возвращает: он существует только ради `export type` и не должен
--- обращаться к Roblox-глобалам. От него зависят `registry`, `codec`, `validator`, `emitter`
--- и UI, поэтому здесь нет ни одного `game:GetService` / `Vector3.new`.

--- Откуда скилл берёт `Animations` / `Sounds` / `Models`.
--- `Stand` переключает набор на `Spec.Data.Assets.Stand`, когда стенд активен.
export type AssetSource = "Spec" | "Stand"

--- Группа блоков в палитре. Порядок групп задан `registry.CATEGORY_ORDER`.
export type Category = "Query" | "Damage" | "State" | "Combat" | "VFX" | "Flow" | "Target"

--- Способ очистки ресурса, созданного блоком.
---
--- Это не булево «чистится / не чистится»: `Buttler:Set` не принимает `nil` (§2.3),
--- а `Sequencer.Buttler` не распознаёт `Cleanup` у `Crane.Janitor` (§2.4), поэтому
--- способ выбирается явно и эмитится по-разному.
export type CleanupStrategy = "Parameter" | "VFXStop" | "Object" | "Janitor" | "None"

--- Базовый тип одного свойства блока.
export type PropertyType =
	"number"
	| "string"
	| "boolean"
	| "Vector3"
	| "CFrame"
	| "Color3"
	| "enum"

--- Тип свойства. Массив означает объединение — например `{ "Vector3", "number" }` у `Hitbox.Size`.
export type PropertyTypeSpec = PropertyType | { PropertyType }

--- Одно редактируемое свойство блока.
---
--- Имя — плоский путь через точку, если свойство принадлежит группе:
--- `Stun.Duration` попадает в `Info.Stun.Duration`. Вложенные секции `AttackInfo`
--- собираются из таких плоских имён эмиттером.
export type BlockProperty = {
	--- Ключ в `PlacedBlock.Properties`.
	Name: string,

	--- Тип значения. Для `enum` обязателен `Options`.
	Type: PropertyTypeSpec,

	--- Значение по умолчанию. `nil` означает «не задано»: блок не эмитит это поле,
	--- пока пользователь его не заполнит.
	Default: any,

	--- Допустимые значения для `enum`. Хранятся строками, а не числами, чтобы
	--- добавление значения в `Enums` не ломало старые JSON (§8).
	Options: { string }?,

	Min: number?,
	Max: number?,
	Step: number?,

	--- Имя опциональной секции (`Stun`, `Knockback`, `Angular`, `Ragdoll`, `Block`).
	--- Секция попадает в результат, только если заполнено хотя бы одно её поле.
	Group: string?,

	--- Свойство обязательно к заполнению. Независимо от `Default`: `Block.*`
	--- имеет `Default = nil`, но остаётся опциональным — частичные секции `Block`
	--- разрешены, потому что у него есть скрытые дефолты (§2.7).
	Required: boolean?,
}

--- Описание одного атомарного блока каталога.
export type BlockDefinition = {
	--- Идентификатор блока; это же значение попадает в `PlacedBlock.Type`.
	Id: string,

	--- Подпись в палитре и на таймлайне.
	DisplayName: string,

	Category: Category,

	--- Короткое объяснение для пользователя: что блок делает и куда пишет результат.
	Description: string,

	--- HEX-строка, а не `Color3`: реестр должен грузиться в `lune`, где `Color3`
	--- не существует (§3). В `Color3` конвертируется только в UI.
	Color: string,

	Properties: { BlockProperty },

	--- Слоты для вложенных блоков. `nil` — вложенность запрещена.
	--- Ключ слота становится ключом в `PlacedBlock.Children`.
	ChildrenSlots: { string }?,

	--- Слоты, из которых должен быть заполнен хотя бы один, иначе блок бессмысленен
	--- (§9, проверка 13). Например у `Repeat` — `Body`, у `ProcessAttack` — `OnSuccess`.
	RequiredSlots: { string }?,

	Cleanup: CleanupStrategy,
}

--- Блок, поставленный пользователем на таймлайн.
---
--- Вложенность хранится плоским списком: слот определяется `Type` родителя
--- (`ProcessAttack` → `OnSuccess` / `OnBlocked` / …, `Branch` → `True` / `False`,
--- `Repeat` → `Body`).
export type PlacedBlock = {
	--- GUID, генерируется на клиенте.
	Id: string,

	--- `Id` блока из реестра.
	Type: string,

	StartFrame: number,

	--- Задан только для `Repeat`.
	EndFrame: number?,

	--- Ключи — плоские имена из `BlockDefinition.Properties`, включая путь группы (`Stun.Duration`).
	Properties: { [string]: any },

	--- Слот → вложенные блоки. `nil`, если вложенность запрещена или не использована.
	Children: { [string]: { PlacedBlock } }?,
}

--- Именованная ссылка на анимацию спеки.
---
--- `AnimationId` хранится строкой: резолв в инстанс выполняется уже в сгенерированном
--- коде (`self.Assets.Animations[slot.AnimationId]`), поэтому blueprint не зависит
--- от содержимого `Spec.Data.Assets` и остаётся переносимым.
export type AnimationSlot = {
	--- Локальный GUID слота, на него ссылается `PlayAnimation.Slot`.
	Id: string,

	--- Отображаемое имя для UI.
	Name: string,

	--- Ключ в `Spec.Data.Assets.Animations`.
	AnimationId: string,

	--- Скорость по умолчанию для анимаций этого слота.
	Speed: number?,

	--- Время затухания при `StopAnimation`. У `onStart` входа `FadeInTime` нет,
	--- применимо только к `onStop` (`effects/Animation.luau:45-53`).
	FadeTime: number?,
}

--- Одна найденная проблема blueprint.
---
--- `Message` пользователь видит в UI и в отчёте CLI, поэтому текст английский;
--- русская формулировка из §9 живёт в коде проверки как обоснование.
export type ValidationIssue = {
	--- Стабильный идентификатор: `E1`–`E20` для ошибок, `W1`–`W7` для предупреждений.
	Code: string,

	--- Текст для пользователя.
	Message: string,

	--- Координаты проблемы внутри blueprint, например
	--- `{ "Blocks", 1, "Children", "OnSuccess", 0, "Properties" }`.
	--- UI по нему подсвечивает узел на таймлайне, CLI печатает тем же путём.
	Path: { string | number },

	--- `PlacedBlock.Id` проблемного блока. `nil` для ошибок уровня скилла.
	BlockId: string?,

	--- Плоское имя свойства без пути группы (`Stun.Duration`), если ошибка о свойстве.
	Property: string?,
}

--- Результат валидации. Ошибки блокируют экспорт, предупреждения — нет (§9).
export type ValidationResult = {
	errors: { ValidationIssue },
	warnings: { ValidationIssue },
}

--- Полное описание скилла: то, что редактируется в UI, экспортируется в JSON
--- и подаётся на вход эмиттеру.
export type SkillBlueprint = {
	--- Идентификатор: ключ в `spec.Skills` и имя файла `<Id>.luau`.
	Id: string,

	--- Отображаемое имя: уходит в `Skill:SetDisplayName`.
	--- По умолчанию совпадает с `Id` без пробелов, но редактируется независимо.
	DisplayName: string,

	Cooldown: number,

	AssetSource: AssetSource,

	--- Теги для `BotService`. Обязателен при наличии `Hitbox`: иначе `Bot.luau:198`
	--- обратится к `data.Skill.Data.SkillCharacters` без nil-защиты (§2.9).
	SkillCharacters: { string },

	AnimationSlots: { AnimationSlot },

	Blocks: { PlacedBlock },

	Metadata: {
		CreatedAt: number,
		UpdatedAt: number,
		--- Формат blueprint. `codec.decode` отказывается принимать версию новее известной.
		Version: number,
	},
}

return nil
