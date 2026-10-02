# Skill Constructor — Техническое задание

> Конструктор скиллов PAC — блочный редактор с таймлайном, экспортирующий данные для генерации `.luau`-скилла.

---

## 1. Назначение и границы

### Что делает

Внутриигровой UI-конструктор, в котором пользователь собирает скилл из атомарных блоков, расставленных по кадрам таймлайна, и получает **экспортируемые данные** (JSON). JSON можно импортировать обратно и продолжить редактирование.

### Как это используется

```
Пользователь (в игре)          Разработчик (в репозитории)
─────────────────────────       ─────────────────────────────
UI-конструктор
  └─ Export JSON  ───────────►  tools/generate-skill.luau
                                   └─► src/server/skills/<Id>.luau
                                        └─► SkillsFolder / спека / Binds
                                             └─► Rojo sync → работает
```

Полная цепочка деплоя — §17.

### Чего конструктор НЕ делает

- **Не генерирует код в рантайме.** `ModuleScript.Source` нельзя задать из скрипта, `loadstring` удалён из Luau.
- **Не отправляет blueprint на сервер.** Нет ни пакетов, ни `BlueprintService`, ни сетевой ревалидации.
- **Не исполняет blueprint в игре.** Боевого теста нет — только превью скомпилированного `Frames` и скраббер по кадрам.
- **Не трогает `CombatService`, хуки, `Character`-компонент, `BotService`.** §14.

### Осознанно не реализуется

| Что | Почему |
|---|---|
| `Heal` / `HealTarget` | healing-системы в проекте нет |
| `SetHealMultiplier` / `SetHealReceivalMultiplier` / `SetCooldownMultiplier` | параметры объявлены в `Parameters.luau:30-32`, но не читаются нигде |
| `SetTimescale` | `CombatService:145` вызывает `AdjustSpeed` один раз при создании sequence |
| `OnIFrames` | `Hooks/IFrames.luau:17-20` обнуляет `State.IFrames` и ставит `Success = false` — недетектируемо. Требует правки `CombatService` |
| `SetCollisionGroup` | дубль `SetNoCollision`; enum-семантика потребовала бы другого контракта — `CollisionService:SetCollisionGroup(group, instance)` (`CollisionService.luau:38`) |
| `Barrage` / `Crash` / `ShowHitbox` | сигнатуры эффектов не соответствуют идее блока (§5, VFX) |
| Студия-плагин для файловых операций | отдельная задача после MVP |
| `AttackInfo` как поле blueprint | §6 |

---

## 2. Ограничения платформы

Каждый пункт проверен по коду и является жёстким ограничением для проектирования.

### 2.1 Нет рантайм-codegen

- `src/server/services/SkillService.luau:52-56` — скиллы грузятся только через `require` из `SkillsFolder`
- `SkillService.CachedData` кэширует по `skillId` (`:48-50`) — **данные общие на все инстансы**
- `src/server/services/SpecService.luau:62-68` — спека перечисляет скиллы и создаёт их только на спавне
- Горячей перезагрузки нет

### 2.2 `Sequencer` — реальные инварианты

`src/shared/packages/Sequencer/init.luau`

| Факт | Место | Следствие |
|---|---|---|
| `Frames` — обычное поле, один раз в конструкторе; API добавления нет | `:341` | эмитер обязан строить весь список заранее |
| `GetFrames` обходит **все** кадры и фильтрует по диапазону `[low, high]` — **порядок в массиве не влияет на то, какие кадры попадут в выборку** | `:192-222` | сортировка `Frames` по номеру **не требуется** |
| `GetFrames` возвращает выборку **в порядке массива**; тело тика исполняет её последовательно | `:242-263` | порядок влияет на **порядок исполнения** в одном Heartbeat |
| Элемент **без колбэка** = терминатор: `self:Stop()` и немедленный `return` из цикла | `:256-259` | всё, что стоит **после** терминатора в том же Heartbeat, **не выполнится** |
| `Play` читает `self.Frames[#self.Frames][1]` | `:266` | **последний элемент массива должен иметь максимальный номер кадра**, иначе sequence не остановится |
| Для много-кадрового элемента `{start, fn, end}` поле `[1]` — это `start`, а не `end` | `:157-159` | если такой элемент последний, `:266` остановит на `start`, а не на `end` |
| Много-кадровая форма дублируется `floor(high) - floor(low)` раз за один Heartbeat, причём аргумент `currentFrame` для всех дублей равен `floor(self.CurrentFrame)` | `:210-217`, `:261` | при длинном тике тело выстрелит N раз, и все с одинаковым `currentFrame`. **Это ограничение самого Sequencer**, оно одинаково влияет и на скиллы, написанные руками |
| Если `high > frameEnd + 1`, тело много-кадрового элемента **пропускается целиком** | `:206-207` | лаг-спайк может «проскочить» `Repeat` целиком. На ручных скиллах ведёт себя так же |
| Колбэк получает `(seq, currentFrame)`, а не только `seq` | `:155`, `:261` | сигнатуры в эмиттере — `(seq, frame)` |
| `Cleaner` (Buttler) чистится в `Stop()` | `:285` | — |
| `Cleaner` **не** содержит `Tick`-соединение — разделяются намеренно | `:281-283` | — |

Три формы кадра:

```lua
{ 30, function(seq, frame) end }        -- один кадр
{ 30, function(seq, frame) end, 35 }    -- каждый кадр в диапазоне
{ 45 }                                  -- терминатор: Stop() + return
```

**Правило для эмитера:** терминатор `{maxFrame}` ставится **последним элементом массива**, чтобы все вызовы тела в этом же Heartbeat отработали до него. `Punch.luau` обходится без терминатора — там последним идёт `{15, function}`, и `:266` срабатывает по его номеру.

### 2.3 Butler: `Set` не принимает `nil`

`src/shared/packages/Crane/packages/Buttler.luau`

```lua
-- :280-282
function Butler:Add<T>(object: T, method: string?, label: string?): T
    assert(object ~= nil, "[Butler] Cannot track nil")

-- :314-317
function Butler:Set<T>(name: string, object: T, method: string?): T
    assert(object ~= nil, "[Butler] Use :Remove(name) to clear a slot; :Set does not accept nil")
```

`VFXService:StartEffect` **возвращает `nil`** (`src/server/services/VFXService.luau:19-29`), поэтому `seq.Cleaner:Set("k", VFXService:StartEffect(...))` упадёт. Правильные паттерны — `Punch.luau:78-84` и `Grab.luau:127`:

```lua
seq.Cleaner:Add(function()
    VFXService:StopEffect(Players:GetPlayers(), "Animation", self.Caster, {
        Animation = Anims["Punch"],
    })
end)

seq.Cleaner:Set("GrabObject", CombatService:CreateGrab(character, self.Target, GrabData))
```

### 2.4 Butler не знает Janitor

`src/shared/packages/Sequencer/Butler.luau:192-219` — авто-детект распознаёт только `Destroy` / `destroy` / `Disconnect` / `disconnect` / `cancel` / `Cancel`. У `Crane.Janitor` выход — `Cleanup()`. Прямая передача Janitor в `Buttler` приведёт к предупреждению `"Table has no recognized cleanup method"`.

### 2.5 Нет JSON-библиотеки

`HttpService:JSONEncode` — единственный доступный JSON, и он не сериализует `Vector3`, `CFrame`, `Color3` нативно. Нужен явный codec (§8).

В проекте JSON используется в 2 местах: `src/server/services/GameDataService.luau:20`, `src/shared/packages/Crane/packages/ByteNet/replicated/replicatedValue.luau:22`.

### 2.6 `AttackData.State` — фактические поля

`src/server/types.luau:110-123` объявляет:

```
Success, Continue, Blocking, Blocked, BlockBroken, PerfectBlocking,
PerfectBlocked, BlockIgnored, IFrames, Armored
```

Фактически в рантайме:

| Поле | Кто пишет | Комментарий |
|---|---|---|
| `BlockCanceled` | `Hooks/Block.luau:23,34` | **есть, но нет в типе** |
| `Ragdolled` | `CombatService:171` | **есть, но нет в типе** |
| `Armored` | `CombatService:169` (`GetStates`) | `Hooks/Armor.luau` его **не затирает** → **детектируемо** |
| `Halt` | никто | **читается в 5 хуках, не пишется нигде** → всегда `nil` |
| `IFrames` | `Hooks/IFrames.luau:19` | **обнуляется** при срабатывании → недетектируемо |

Следствия:

- **`OnIFrames` невозможен** — исключён из каталога.
- **`OnArmored` и `OnRagdolled` доступны.** `Hooks/Armor.luau:16-27` в `Precast` только зануляет `Info.{Ragdoll,Stun,Knockback,Angular}` и ставит `Continue = false`, но `State.Armored` остаётся `true`.
- **`Success` при брони остаётся `true`.** Значит `OnSuccess` сработает на бронированной цели, хотя эффекты не применились. Поэтому `OnSuccess` требует **дополнительного** условия `State.Continue` — это отражено в §5.
- **`PerfectBlocked` ≠ `PerfectBlocking`.** `PerfectBlocked` — наказание атакующему (`Block.luau:38-40`), `PerfectBlocking` — состояние цели. Противоположные флаги.

### 2.7 Дефолты `AttackInfo` — только у `Block`

`Hooks/Block.luau:24-29` — единственное место с `Crane.Utils.Reconcile`:

```lua
local DefaultBlock = {
    Blockable = true,
    PerfectBlockable = true,
    BlockBreak = false,
    BlockCancel = false,
    BlockIgnore = false,
}
local Block = Crane.Utils.Reconcile(Data.Info.Block or {}, DefaultBlock)
```

`Punch.luau:112-115` передаёт `Block = { PerfectBlockable = false }` — **одно поле из пяти**, и это штатный паттерн. Значит частичные `Block` разрешены: UI обязан показывать **эффективные** значения (дефолт + оверрайд), а валидатор — требовать только корректности переданных полей.

Остальные секции `AttackInfo` дефолтов не имеют и передаются как есть.

### 2.8 Баг `SetNoCollision(false)` — core не трогаем

`src/server/components/Character/Watchers.luau:63-69`:

```lua
["NoCollision"] = function(self, value, object)
    self:SetCollisionToPlayers(value ~= nil and value or true)
end
```

`false` схлопывается в `true`. Блок `SetNoCollision` существует, но **принимает только `true`**; валидатор отклоняет `false`.

### 2.9 `Hitbox` обязан передавать `Skill`

`src/server/services/CombatService/init.luau:59-61`:

```lua
if Skill then task.spawn(function()
    self.Casted:Fire(Data)
end) end
```

`Casted` стреляет **только** при непустом `Skill`. `Punch.luau:94` и `Grab.luau:223` его передают. Без этого:

- боты не реагируют на атаки (`BotService/Bot.luau:196-223`)
- `Bot.luau:198` обращается к `data.Skill.Data.SkillCharacters` **без nil-защиты** → рантайм-ошибка на любом `Casted` от скилла без `SkillCharacters`

Также `Bot.luau:201-202` вычисляет позицию хитбокса:

```lua
local hitboxPos = data.Info.Origin and data.Info.Origin.Position
    or (self.Target.RootPart.CFrame * data.Info.Offset).Position
```

Отсутствие `Origin` в эмите → бот считает хитбокс в другой точке. Поэтому `Origin` — обязательное свойство блока `Hitbox`.

### 2.10 Лимиты сети (нерелевантно, зафиксировано)

Транспорта в конструкторе нет. Если появится расширение:

- `ByteNet.string` — длина в 2 байта (`dataTypes/string.luau:9-21`) → **u16, максимум 65535 байт**
- `MAX_BUFFER_SIZE` читается из атрибута (`ByteNet/process/server.luau:14`) и **отсутствует в репозитории** → `math.floor(nil)` упадёт. Существующий баг, вне scope
- `ByteNet.unknown` кладёт значение в `references` и передаёт его **вторым аргументом** `RemoteEvent` (`process/server.luau:218`) → `Vector3`/`CFrame`/`Instance`/`Sound` проходят нормально, u16-лимит их не касается

---

## 3. Архитектура

### Слои

```
src/shared/packages/SkillConstructor/
├── init.luau            реэкспорт всего
├── types.luau           SkillBlueprint, PlacedBlock, AnimationSlot, BlockDefinition
├── registry.luau        26 блоков: свойства, CleanupStrategy, ChildrenSlots
├── codec.luau           blueprint ↔ JSON (type-tag для Vector3/CFrame/Color3)
├── validator.luau       validateStructural + validateAgainstSpec + checkAgainstSpec
├── tests/
│   ├── structural.luau  проверки 1–20 и W1–W6, dual-environment
│   ├── against-spec.luau проверки 21–23, 25–27 и W7, dual-environment
│   └── emitter.luau      генерация: каркас модуля, Frames, Preview, Errors
└── emitter.luau         blueprint(JSON) → Luau-исходник + Frames-превью

src/client/ui/components/SkillConstructor/
├── init.luau            корневой компонент

├── Theme.luau           цвета, шрифт, отступы, анимации
├── Store.luau           состояние редактора и мутации blueprint
├── Command.luau         определение Cmdr-команды и переход на страницу
├── BlockPalette.luau    палитра блоков по категориям
├── Timeline.luau        линейка, дорожка, playhead, zoom
├── BlockInstance.luau   плашка блока с вложенностью
├── PropertiesPanel.luau  динамическая форма свойств
├── SkillSettings.luau   DisplayName, Cooldown, AssetSource, SkillCharacters
├── AnimationSlotsManager.luau
├── PreviewTab.luau      Frames + скраббер + .luau + проверки против спеки
├── Toolbar.luau
└── ContextMenu.luau

tools/generate-skill.luau   CLI: JSON-файл → src/server/skills/<Id>.luau
```

`AttackInfoEditor.luau` **удалён** — `AttackInfo` больше не часть модели данных (§6).

### Ключевое решение: emitter работает поверх JSON

`emitter.luau` принимает **JSON-форму** (только числа, строки, булевы, массивы, объекты) и печатает `Vector3.new(x, y, z)` как **текст**.

Он никогда не конструирует Roblox-типы. Поэтому один и тот же модуль:
- в игре: `codec.encode(blueprint)` → `emitter.emit(json)` → показать в PreviewTab
- в `tools/`: прочитать JSON-файл → `emitter.emit(json)` → записать `.luau`

Запуск `tools/generate-skill.luau` не требует Roblox API — достаточно `lune` или любого Luau-интерпретатора.

### Следствие: в registry нет Roblox-типов

`BlockDefinition.Color` хранится **hex-строкой** (`"#4FC3F7"`), а не `Color3` — в `lune` (реально установлен) типа `Color3` не существует. Конвертация в `Color3` происходит только в UI.

`registry` не должен требовать `game:GetService` или любых Roblox-глобалов на этапе загрузки.

---

## 4. Модель данных

### SkillBlueprint

```luau
export type AssetSource = "Spec" | "Stand"

export type SkillBlueprint = {
    Id: string,                       -- идентификатор, попадает в путь спеки
    DisplayName: string,              -- отображаемое имя
    Cooldown: number,

    AssetSource: AssetSource,         -- откуда брать Animations/Sounds/Models
    SkillCharacters: { string },      -- теги для BotService; нужен при наличии Hitbox

    AnimationSlots: { AnimationSlot },
    Blocks: { PlacedBlock },
    Metadata: { CreatedAt: number, UpdatedAt: number, Version: number },
}
```

`Id` и `DisplayName` — разные вещи. `Id` используется как ключ в `spec.Skills` (`specs/Standless.luau:10-20`) и как имя файла. `DisplayName` уходит в `Skill:SetDisplayName` (`Skill.luau:78-83`) и в UI. По умолчанию `Id = DisplayName` без пробелов, но редактируются независимо.

`SkillCharacters` — массив строк-тегов. Допустимые значения берутся из `src/shared/bot-characters.luau`. При наличии блока `Hitbox` список не должен быть пустым, иначе `Bot.luau:198` упадёт (§2.9). При создании скилла UI предлагает `{"Hit"}` по умолчанию.

`Tag` **удалён** из модели: `Skill:Init:124` не включает скилл с тегом, пока кто-то не вызовет `Spec:SetEnableSkills(tag, true)` (`Spec.luau:69-73`). Механизма в конструкторе для этого нет, поэтому поле убрано, а эмиттер всегда пишет `Tag = nil`.

### PlacedBlock

```luau
export type PlacedBlock = {
    Id: string,                      -- GUID, генерируется на клиенте
    Type: string,                    -- Id блока из registry
    StartFrame: number,              -- >= 0
    EndFrame: number?,               -- > StartFrame, только для Repeat
    Properties: { [string]: any },
    Children: { PlacedBlock }?,
}
```

Вложенность хранится **плоским списком с `Children` как массивом**, а не как `OnSuccess`/`OnBlocked`-словарь. Слот определяется `Type` родителя: у `ProcessAttack` — `["OnSuccess","OnBlocked","OnBlockBroken","OnBlockCanceled","OnPerfectBlocked","OnArmored","OnRagdolled"]`, у `Branch` — `["True","False"]`. Это позволяет таймлайну и палитре обрабатывать вложенность единообразно.

### AnimationSlot

```luau
export type AnimationSlot = {
    Id: string,
    Name: string,            -- отображаемое, для UI
    AnimationId: string,     -- ключ в Spec.Data.Assets.Animations
    Speed: number?,
    FadeTime: number?,       -- только для StopAnimation (effects/Animation.luau:15-20)
}
```

`AnimationId` — строка, не `Animation`. Резолв в инстанс происходит в сгенерированном коде: `self.Assets.Animations[slot.AnimationId]`.

`FadeInTime` **удалён**: `effects/Animation.luau:32-43` принимает `{ Animation, Speed }` — входного `FadeInTime` у `onStart` нет. `FadeTime` применим только к `onStop` (`:45-53`).

### BlockDefinition

```luau
export type CleanupStrategy = "Parameter" | "VFXStop" | "Object" | "Janitor" | "None"

export type BlockProperty = {
    Name: string,
    Type: "number" | "string" | "boolean" | "Vector3" | "CFrame" | "Color3" | "enum",
    Default: any,
    Options: { string }?,
    Min: number?,
    Max: number?,
    Step: number?,
    Group: string?,          -- опциональная группа: эмитится, если заполнено хоть одно поле
}

export type BlockDefinition = {
    Id: string,
    DisplayName: string,
    Category: Category,
    Description: string,
    Color: string,                       -- hex-строка, НЕ Color3 (§3)
    Properties: { BlockProperty },
    ChildrenSlots: { string }?,          -- nil = вложенность запрещена
    Cleanup: CleanupStrategy,
    RequiredSlots: { string }?,          -- слоты, которые обязаны быть заполнены
}
```

`Cleanup` — не булево «Cleaner: Да/Нет», а **способ очистки**, потому что `Buttler:Set` не принимает `nil` (§2.3) и не знает `Janitor` (§2.4):

| Значение | Как эмитится | Пример |
|---|---|---|
| `Parameter` | `seq.Cleaner:Add(character:AddParameter(...))` | `SetMaxWalkSpeed` |
| `VFXStop` | `seq.Cleaner:Add(function() VFXService:StopEffect(...) end)` | `PlayAnimation`, `PlaySound` |
| `Object` | `seq.Cleaner:Add(obj, "Destroy")` | `CreateGrab` |
| `Janitor` | `seq.Cleaner:Add(function() J:Clean() end)` | `AddArmor` |
| `None` | ничего не создаёт | `Hitbox`, `Wait` |

`Group` позволяет описывать опциональные секции `AttackInfo` (`Stun`, `Knockback`, `Angular`, `Ragdoll`) — они попадают в `Info` только если пользователь что-то заполнил.

`RequiredSlots` — слоты `ProcessAttack`, которые должны быть непустыми, если блок вообще используется (валидация §9).

### Category

```luau
export type Category = "Query" | "Damage" | "State" | "Combat" | "VFX" | "Flow" | "Target"
```

---

## 5. Каталог блоков (27)

Все подписи сверены с исходниками. Столбец «Источник» — файл, определяющий контракт.

### Query (1)

| Блок | Свойства | Cleanup | Источник |
|---|---|---|---|
| `Hitbox` | `Size` (`Vector3 \| number`), `Origin` (`CFrame`), `Offset` (`CFrame`), `SortByDistance` (bool), `MaxTargets` (number), `CanQueryCaster` (bool), `MovementCorrection` (bool), `Debug` (bool) | `None` | `CombatService:Hitbox` `:49-125`, `HitboxData.Info` `types.luau:53-62` |

Результат пишется в `seq.Ctx.Targets`.

- `Size = number` → `GetPartBoundsInRadius` (`:96`); `Vector3` → `GetPartBoundsInBox` (`:99`)
- `SortByDistance` реализован в `:116-121`
- **`MaxTargets` в `HitboxData.Info` отсутствует** — обрезку эмитер обязан делать сам, после вызова
- `Origin` читает бот (`Bot.luau:201-202`) — см. §2.9
- `Debug` включает визуализацию `:123`
- `Skill = self` **обязательно** передаётся — см. §2.9

Хелперы `GetClosestTarget` / `GetTargetsInRadius` **поглощены** — они были обёртками над тем же вызовом.

### Damage (1)

| Блок | Свойства | Cleanup | Источник |
|---|---|---|---|
| `ProcessAttack` | `Priority`, `Damage`, `Stun{Duration,Priority}`, `Knockback{...}`, `Angular{...}`, `Ragdoll{Duration}`, `Block{...}` | зависит от детей | `CombatService:Attack` `:128-140` |

Форма `Info` собирается по образцу §6. Блок выполняет **один** вызов `CombatService:Attack` на каждую цель из `seq.Ctx.Targets`.

Вложенные слоты (только реально наблюдаемые поля `AttackData.State`):

| Слот | Условие | Источник |
|---|---|---|
| `OnSuccess` | `State.Success and State.Continue` | `Success` — `Block.luau:22`; `Continue` обязателен, т.к. при брони `Success` остаётся `true` (§2.6) |
| `OnBlocked` | `State.Blocked` | `Block.luau:42` |
| `OnBlockBroken` | `State.Blocked and State.BlockBroken` | `Block.luau:44` |
| `OnBlockCanceled` | `State.BlockCanceled` | `Block.luau:34` |
| `OnPerfectBlocked` | `State.PerfectBlocked` | `Block.luau:39` |
| `OnArmored` | `State.Armored` | `GetStates:169`; хук не затирает (§2.6) |
| `OnRagdolled` | `State.Ragdolled` | `GetStates:171` |

`OnIFrames` исключён (§2.6). Отдельных блоков `ApplyStun` / `ApplyKnockback` / `ApplyRagdoll` нет намеренно: `AttackInfo` подаётся одним вызовом, разделение породило бы N вызовов `Attack` на цель = N наложений урона. Атомарность сохранена на уровне полей.

### State (10)

Все через `character:AddParameter(...)` → `Cleanup: "Parameter"`.
Значения — `src/server/components/Character/Parameters.luau`.

| Блок | Свойство | Параметр | Примечание |
|---|---|---|---|
| `SetIFrames` | `Level` (enum) | `IFrames` | `Enums.IFrames`: `Ragdoll=10`, `Dodge=15`, `Grab=50`, `True=10000`. Сравнивается с `Info.Priority` в `Hooks/IFrames.luau:17` — это **уровень**, не длительность |
| `SetDamageMultiplier` | `Value` | `DamageMultiplier` | `Hooks/Damage.luau:16` |
| `SetDamageReceivalMultiplier` | `Value` | `DamageReceivalMultiplier` | `Hooks/Damage.luau:17` |
| `SetMaxWalkSpeed` | `Value` | `MaxWalkSpeed` | `Watchers.luau:10-18`, `LowestParser` |
| `SetMinWalkSpeed` | `Value` | `MinWalkSpeed` | `Watchers.luau:14-16`, `HighestParser` |
| `SetMaxJumpPower` | `Value` | `MaxJumpPower` | `Watchers.luau:24-28`, фактический потолок 50 |
| `SetArmor` | `State` (bool) | `Armor` | проверяется в `Hooks/Armor.luau:20` |
| `SetRagdoll` | `State` (bool) | `Ragdoll` | `Watchers.luau:48-61`, тянет за собой `IFrames.Ragdoll` |
| `SetNoCollision` | `State` (**только `true`**) | `NoCollision` | баг `false` — §2.8 |
| `SetRestrain` | `State` (bool) | `Restrain` | `Watchers.luau:71-84` |

### Combat (2)

| Блок | Свойства | Cleanup | Источник |
|---|---|---|---|
| `AddArmor` | — | `Janitor` | `CombatService:AddArmor` `:179-197`. Возвращает `Crane.Janitor`, **не принимает Duration** |
| `CreateGrab` | `AttackerRestrain`, `VictimRestrain` (bool), `BindMode` (enum `None`/`RootToRoot`), `Offset` (`CFrame`) | `Object` | `CombatService:CreateGrab` `:199-265`, возвращает `Buttler` |

`BindMode` решает проблему `types.luau:40-52`: `GrabData.Victim.Bind` требует `Part0`/`Part1` как `BasePart`, а `CombatService:CreateGrab:239-249` строит по ним `AlignPosition`/`AlignOrientation`. Blueprint не содержит `Instance`, поэтому эмиттер подставляет части сам:

```lua
-- BindMode = "RootToRoot", Offset = CFrame.new(0, 0, -4)
CombatService:CreateGrab(character, Target, {
    Attacker = { Restrain = <AttackerRestrain> },
    Victim = {
        Restrain = <VictimRestrain>,
        Bind = {
            Part0 = character.RootPart,
            Part1 = Target.RootPart,
            Offset = CFrame.new(0, 0, -4),
        },
    },
})
```

Это покрывает `Grab.luau:127-143` без `Instance` в данных. `BindMode = "None"` → `Victim` без `Bind` (захват без физической привязки).

### VFX (6)

Все через `VFXService:StartEffect` → `Cleanup: "VFXStop"`, кроме `StopAnimation` (`None`).

| Блок | Свойства | Источник | Notes |
|---|---|---|---|
| `PlayAnimation` | `Slot` (ссылка на `AnimationSlot`), `Speed` | `effects/Animation.luau:32-43` | вход — `{ Animation, Speed }` |
| `StopAnimation` | `Slot`, `FadeTime` | `effects/Animation.luau:45-53` | останавливает явно, `Cleanup: "None"` |

| `PlaySound` | `Sound` (string), `Volume`, `MaxDistance`, `MinDistance` | `effects/Sound.luau:23-51` | |
| `EmitParticle` | `Particle` (string), `Origin` (`Caster`/`Target`/`CFrame`), `Offset` (`CFrame`), `UseForge` (bool) | `effects/EmitParticle.luau:27-92` | `UUID` **не обязателен** (`:55` `if Data.UUID then`) — нужен только для `onStop` (`:88`). Эмиттер генерирует его всегда, чтобы блок можно было останавливать. `Particle` резолвится в `Assets.Models[...]` → `BasePart` |
| `EmitFolder` | `Folder` (string), `Origin` (`Caster`/`Target`) | `effects/EmitFolder.luau:8-46` | `uuid: string?` для `onStop` — генерируется автоматически |
| `Highlight` | `FillColor`, `OutlineColor`, `FillTransparency`, `OutlineTransparency`, `Lifetime` | `effects/Highlight.luau:5-59` | Поле называется **`Lifetime`**, не `Duration` |

Исключены: `PlayDashAnimation` (`Skins[SpecId][SkinId]` плюс ручной `BodyVelocity` в `Dash.luau:72-79` — вне модели данных), `Barrage` (`onStart(character)` без параметров, `effects/Barrage.luau:4-11`), `Crash` (`onStart(object: Model, projectile: Model)`, `effects/Crash.luau:10`), `ShowHitbox` (дублирует `Hitbox.Debug`, `effects/Hitbox.luau:7-27`).

### Flow (4)

| Блок | Свойства | Cleanup | Notes |
|---|---|---|---|
| `Wait` | — | `None` | Только маркер конца sequence. Не эмитится в выход, влияет на `maxFrame` (§7) |
| `Repeat` | `StartFrame`, `EndFrame` | `None` | Много-кадровая форма `{start, fn, end}`. **Родитель вложенных блоков** |
| `Branch` | `Condition` (string) | `None` | Слоты `True` / `False`. **Родитель вложенных блоков** |
| `CustomCallback` | `Code` (string) | `None` | Вставляется в тело callback как есть |

`Condition` и `Code` — сырые строки, попадают в сгенерированный `.luau` **дословно**. Осознанный escape hatch; UI помечает такие блоки иконкой, валидатор возвращает `warnings`.

### Target (2)

| Блок | Свойства | Cleanup | Notes |
|---|---|---|---|
| `FilterTargets` | `MaxTargets`, `SortByDistance` | `None` | Мутирует `seq.Ctx.Targets` на месте |
| `ClearTargets` | — | `None` | `seq.Ctx.Targets = {}` |

### Итог

| Категория | Кол-во |
|---|---|
| Query | 1 |
| Damage | 1 |
| State | 10 |
| Combat | 2 |
| VFX | 6 |
| Flow | 4 |
| Target | 2 |
| **Итого** | **26** |

---

## 6. `AttackInfo` — справочник формы, не поле blueprint

`AttackInfo` **не хранится в blueprint** — пользователь не заполняет его руками. Но в сгенерированном модуле поле **есть**: `types.SkillData.AttackInfo` читают `Grab.luau:74` и `TEMPLATE.luau:57`, и без него модуль не проходит тип-чекер. Причина: `self.Data.AttackInfo` читают только `Grab.luau:74` и `TEMPLATE.luau:57` — то есть тело самого скилла. Эмиттер собирает шапку из `ProcessAttack`: **первое непустое значение поля побеждает**, потому что два разных удара честно не сводятся к одному `AttackInfo`. Если непустых значений нет — печатается `AttackInfo = {}`. `Info` внутри тела атаки, наоборот, собирается только из самого блока: общей таблицы у вызовов нет (§7).

Вместо этого справочник задаёт **форму `Info`**, которую собирает `ProcessAttack`, и служит источником значений по умолчанию в UI.

### Форма `Info` (сверена с `types.luau:65-104` и хуками)

```luau
{
    Priority = number,
    Damage = number,

    Hitbox = {
        Size = Vector3 | number,
        Offset = CFrame?,
        Origin = CFrame?,
        SortByDistance = boolean?,
        CanQueryCaster = boolean?,
        MovementCorrection = boolean?,
        Debug = boolean?,
    },

    Stun = {
        Duration = number,
        Priority = number,        -- Enums.Stun
    },

    Block = {
        Blockable = boolean,
        PerfectBlockable = boolean,
        BlockBreak = boolean,
        BlockCancel = boolean,
        BlockIgnore = boolean,
    },

    Knockback = {
        RelativePart = "Attacker" | "Target",
        RelativeTowards = "Attacker" | "Target",
        LookVector = Vector3,                 -- Hooks/Knockback.luau:24
        Origin = CFrame?,                     -- :43-45
        ToFront = number,                     -- :48 — ДИСТАНЦИЯ, не bool
        Speed = number,
        Duration = number,
        Velocity = Vector3,
        MaxForce = Vector3,                   -- дефолт (100000,100000,100000) — :61-62, :87-88
    },

    Angular = {
        Velocity = Vector3,
        Speed = number?,
        Duration = number?,
        MaxTorque = number?,
    },

    Ragdoll = { Duration = number },
}
```

### Что было исправлено относительно реальности

| Поле | Статус | Обоснование |
|---|---|---|
| `Hitbox` | есть | Используется 8 скиллами как `Info = AttackInfo.Hitbox`: `Grab.luau:225`, `ArcSpearStrike.luau:104`, `Uppercut.luau:109`, `CircularKick.luau:153`, `Footrest.luau:101`, `Bonk.luau:118`, `WaitALittleBit.luau:124`, `TEMPLATE.luau:93` |
| `Knockback.LookVector` | есть | `Hooks/Knockback.luau:24` |
| `Knockback.ToFront` | **число**, не bool | `Hooks/Knockback.luau:48` — дистанция в `LookVector + LookVector * ToFront` |
| `FindCrashObject` | **удалён** | Мёртвое поле: `Grab.luau:50` закомментировано, нигде не читается |
| `Block` (5 полей) | **все опциональны** | Дефолты в `Hooks/Block.luau:24-29` существуют именно ради частичных передач; `Punch.luau:112-115` передаёт одно поле |
| `Ragdoll`, `Angular` | опциональны | Передаются только если заполнены |

### Семантика выполнения

1. `CombatService:Attack:133-134` клонирует переданный `Info` в `OriginalInfo` / `Info`
2. Хуки **`Precast`** (`Block`, `Armor`, `IFrames`) могут занулить поля `Info`
3. Хуки **`Cast`** (`Damage`, `Stun`, `Ragdoll`, `Angular`, `Knockback`) применяют эффекты, проверяя `State.Success` и `State.Halt`
4. `Attack` **мутирует** `Info` (например `Damage.luau:16-17` домножает `Damage`)

Следствие: эмиттер обязан генерировать **свежий table-литерал `Info` на каждый вызов**, иначе мутация попадёт в следующий кадр.

---

## 7. Эмитер: blueprint → Frames

### Per-cast состояние: `seq.Ctx`

Ни `ctx`, ни любой аналог в репозитории не существует (0 совпадений по `src/`). В репо аналогичное состояние (`self.AlreadyHit`) чистят вручную на кадре 0 — `Punch.luau:54`, `Grab.luau:200`, `Barrage.luau`, `WaitALittleBit.luau`.

В эмитере per-cast состояние живёт на **`seq.Ctx`**, а не на `self`:

```lua
function Skill:onInit()
    local character = self.Character
    ...
    self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
        Frames = {
            --[1] ОБЯЗАТЕЛЬНЫЙ preamble: сбрасывает per-cast состояние
            { 0, function(seq)
                seq.Ctx = { Targets = {} }
            end },

            --[2] блоки пользователя
            ...
        },
    }))
end
```

Правила:

- preamble **эмитится всегда**, даже если пользователь не поставил ни одного блока на кадр 0 — иначе `Repeat`/`Branch` не имеют правила сброса
- конкурентные активации невозможны: `Spec:ActivateSkill:113` через `CheckActiveSkills` не даёт запустить второй активный скилл
- `seq.Ctx` пересоздаётся на каждом `Play()` (сброс при старте), `Stop()` его не чистит — это безопасно, так как следующий `Play()` пересоздаст
- любой блок, читающий или пишущий `Targets`, обязан иметь fallback: `local Targets = seq.Ctx.Targets or {}` — на случай если preamble был обойдён

### Порядок работы эмитера

```
1. Обойти дерево блоков в глубину
     - StartFrame дочернего = max(StartFrame, StartFrame родителя)
2. Сгруппировать верхнеуровневые блоки по StartFrame
3. Отсортировать группы по возрастанию   (порядок не влияет на выборку §2.2,
                                         но нужен для предсказуемости вывода)
4. Для каждой группы слить блоки в один callback
5. Repeat развернуть в много-кадровую форму {start, fn, end}
6. Вычислить maxFrame = max(60, max(StartFrame), max(Repeat.EndFrame))
7. Добавить терминатор {maxFrame} ПОСЛЕДНИМ элементом массива
```

Пункт 7 обязателен: без терминатора последний много-кадровый элемент даст `[1] = start` и `Play:266` остановит sequence на `start` вместо `end` (§2.2). Терминатор ставится последним, чтобы вызовы тела в том же Heartbeat отработали **до** `Stop()` — `Play:256-259` делает немедленный `return`.

### Порождение callback

```lua
-- Hitbox  (Skill = self обязателен — §2.9)
local Targets = CombatService:Hitbox({
    Skill = self,
    Caster = character,
    Info = {
        Size = Vector3.new(7, 7, 7),
        Origin = CFrame.new(0, 0, 0),
        Offset = CFrame.new(0, 0, -3),
        SortByDistance = true,
        MovementCorrection = true,
        Debug = true,
    },
})

local Hit = {}
for _, Target in Targets do
    if #Hit >= 2 then break end      -- MaxTargets: обрезка вручную, в API её нет
    table.insert(Hit, Target)
end
seq.Ctx.Targets = Hit

-- ProcessAttack
for _, Target in Targets do
    CombatService:Attack({
        Attacker = character,
        Victim = Target,
        Info = { ... },             -- свежий литерал на каждый вызов
    }):andThen(function(Data)
        if Data.State.Success and Data.State.Continue then
            -- <дети OnSuccess>
        end
        if Data.State.Blocked then
            -- <дети OnBlocked>
        end
        if Data.State.Blocked and Data.State.BlockBroken then
            -- <дети OnBlockBroken>
        end
        if Data.State.BlockCanceled then
            -- <дети OnBlockCanceled>
        end
        if Data.State.PerfectBlocked then
            -- <дети OnPerfectBlocked>
        end
        if Data.State.Armored then
            -- <дети OnArmored>
        end
        if Data.State.Ragdolled then
            -- <дети OnRagdolled>
        end
    end)
end
```

Условия слотов **статические** — слоты известны на этапе генерации, пустые не эмитятся.

```lua
-- Repeat → много-кадровая форма
{ StartFrame, function(seq, frame)
    -- <тело>
  end, EndFrame }

-- Branch
if (CONDITION) then
    -- <дети True>
else
    -- <дети False>
end
```

### Cleanup по стратегиям

```lua
-- Parameter
seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 8))

-- VFXStop  (StartEffect возвращает nil → только Add(function))
seq.Cleaner:Add(function()
    VFXService:StopEffect(Players:GetPlayers(), "Animation", character.instance, {
        Animation = Anims["Punch"],
    })
end)

-- Object
seq.Cleaner:Add(CombatService:CreateGrab(character, Target, GrabData))

-- Janitor  (Buttler не знает Cleanup — §2.4)
local Armor = CombatService:AddArmor(character)
seq.Cleaner:Add(function() Armor:Clean() end)

-- VFX с UUID: счётчик, не os.clock()
local ParticleUUID = NextUuid()
VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", {
    UUID = ParticleUUID,
    Particle = Models["Hit"],
    Origin = Target.RootPart,
})
seq.Cleaner:Add(function()
    VFXService:StopEffect(Players:GetPlayers(), "EmitParticle", ParticleUUID)
end)
```

`NextUuid()` — монотонный счётчик в области видимости модуля скилла. `os.clock()` может вернуть одинаковое значение в пределах тика — в репо так и сделано (`CombatService:184`), но генератору доступен счётчик, поэтому он используется.

Имена для `Buttler:Set` (`Grab.luau:127` — `"GrabObject"`) генерируются из `Type` + порядковый номер: `"Hitbox_1"`, `"Grab_2"`. Пользователь в этом не участвует.

### Stand-ассеты

`Punch.luau:37,156`:

```lua
local StandService = Crane:GetService("StandService")
local Stand = StandService:GetStand(self.Character)
local IsStandActive = if Stand then Stand:IsActive() else false

self.Assets = if IsStandActive then self.Spec.Data.Assets.Stand or self.Spec.Data.Assets
    else self.Spec.Data.Assets
local Anims = self.Assets.Animations
local Sounds = self.Assets.Sounds
local Models = self.Assets.Models
```

Блок преамбулы генерируется, только если `AssetSource == "Stand"`. При `AssetSource == "Spec"` эмиттится короткая форма:

```lua
local Anims = self.Spec.Data.Assets.Animations
local Sounds = self.Spec.Data.Assets.Sounds
local Models = self.Spec.Data.Assets.Models
```

Валидация 17-19 в §9 идёт **по выбранному набору** ассетов.

### Структура выходного модуля

```lua
--!native
--!optimize 2

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Enums = require(ServerScriptService.server.Enums)
local types = require(ServerScriptService.server.types)

local Skill: types.SkillData = {
    DisplayName = "Fire Punch",
    Cooldown = 3,
    Tag = nil,

    SkillCharacters = { "Hit" },

    AttackInfo = {
        Damage = 15,
        Stun = { Duration = 0.7, Priority = Enums.Stun.Medium },
        Block = { Blockable = true, PerfectBlockable = false },
    },
}

function Skill:onInit()
    local character = self.Character
    local RootPart = character.RootPart
    local CombatService = Crane:GetService("CombatService")
    local VFXService = Crane:GetService("VFXService")
    local StandService = Crane:GetService("StandService")

    local Stand = StandService:GetStand(self.Character)
    local IsStandActive = if Stand then Stand:IsActive() else false

    self.Assets = if IsStandActive then self.Spec.Data.Assets.Stand or self.Spec.Data.Assets
        else self.Spec.Data.Assets
    local Anims = self.Assets.Animations
    local Sounds = self.Assets.Sounds
    local Models = self.Assets.Models

    self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
        Frames = { ... },
    }))
end

function Skill:Activate()
    if self.Sequence then
        self.Sequence:Play()
        self.Sequence:Await()
    end
end

function Skill:Interrupt()
    if self.Sequence then self.Sequence:Stop() end
end

function Skill:onDestroy()
    if self.Sequence then self.Sequence:Destroy() end
end

return Skill
```

Требования к шапке:

- `--!native` / `--!optimize 2` — боевой код на сервере, как в `Skill.luau:1-2` и `CombatService/init.luau:1-2`
- `local Skill: types.SkillData` — иначе файл не проверить типами: `types.luau:280-292` требует `Id`, `SkillCharacters`, `onDestroy`, `Activate`, `Interrupt`
- `Id` проставляет `SkillService:57` (`data["Id"] = skillId`) — вручную писать не нужно
- `AttackInfo` в модуле **есть** и читается телом — это единственное законное место для него; блоки его не читают
- `onDestroy` обязателен (`types.luau:289`); `Skill:Destroy:130` вызывает его перед `Cleaner:Destroy()`
- Локалы в **PascalCase** как в репо (`character`, `RootPart`, `CombatService`, `Anims`), несмотря на `camelCase` в общих правилах — эмиттер следует стилю существующих скиллов, §14
- `require`-блоки и локалы `Anims`/`Sounds`/`Models` вычисляются **по фактическому использованию**: пустой `AttackInfo` не тянет `Enums`, blueprint без `CreateGrab` не тянет `types`

---

## 8. Сериализация

### Структура JSON

```json
{
  "Id": "FirePunch",
  "DisplayName": "Fire Punch",
  "Cooldown": 3,
  "AssetSource": "Spec",
  "SkillCharacters": ["Hit"],
  "AnimationSlots": [
    { "Id": "a1b2", "Name": "Punch", "AnimationId": "Punch", "Speed": 1, "FadeTime": null }
  ],
  "Blocks": [
    {
      "Id": "blk_01",
      "Type": "PlayAnimation",
      "StartFrame": 0,
      "EndFrame": null,
      "Properties": { "Slot": "a1b2" },
      "Children": null
    },
    {
      "Id": "blk_02",
      "Type": "ProcessAttack",
      "StartFrame": 15,
      "EndFrame": null,
      "Properties": {
        "Damage": 15,
        "Stun": { "Duration": 0.7, "Priority": 20 },
        "Block": { "Blockable": true, "PerfectBlockable": false }
      },
      "Children": {
        "OnSuccess": [
          {
            "Id": "blk_03",
            "Type": "EmitParticle",
            "StartFrame": 15,
            "EndFrame": null,
            "Properties": { "Particle": "Hit", "Origin": "Target" },
            "Children": null
          }
        ]
      }
    }
  ],
  "Metadata": { "CreatedAt": 0, "UpdatedAt": 0, "Version": 1 }
}
```

`AttackInfo` в JSON **отсутствует** — его форма живёт в свойствах `ProcessAttack` (§6).

### Codec для несериализуемых типов

`HttpService:JSONEncode` не понимает `Vector3`, `CFrame`, `Color3`. Используется type-tag:

```json
{ "$": "V3", "x": 0, "y": 0, "z": -3 }
{ "$": "CF", "px": 0, "py": 0, "pz": 0, "rx": 0, "ry": 0, "rz": 0 }
{ "$": "C3", "r": 1, "g": 1, "b": 1 }
```

| Тип | Формат | Плейсхолдер в Luau-исходнике |
|---|---|---|
| `Vector3` | `{ "$": "V3", "x", "y", "z" }` | `Vector3.new(x, y, z)` |
| `CFrame` | `{ "$": "CF", "px", "py", "pz", "rx", "ry", "rz" }` | `CFrame.new(px, py, pz) * CFrame.fromEulerAnglesYXZ(rx, ry, rz)` |
| `Color3` | `{ "$": "C3", "r", "g", "b" }` | `Color3.fromRGB(r * 255, g * 255, b * 255)` |

Сериализуются нативно, без tag: `string`, `number`, `boolean`, `nil`/`null`, вложенные массивы и объекты.

Tag для `Instance` / `BasePart` **не требуется** — проблема `CreateGrab.Bind` решена через `BindMode` (§5, Combat).

`rx`, `ry`, `rz` — радианы в порядке `YXZ`, как у `CFrame:ToOrientation()`. Пересборка через `CFrame.fromEulerAnglesYXZ` обязательна: у `CFrame.new` нет перегрузки с шестью аргументами, а прямой `CFrame.Angles(rx, ry, rz)` дал бы другой порядок осей.

`enum`-свойства хранятся **строкой** (`"Medium"`, `"RootToRoot"`, `"Heavy"`), а не числом — чтобы добавление нового значения в `Enums` не ломало старые JSON.

`AnimationId` — строка; резолв в `Animation` в сгенерированном коде через `self.Assets.Animations[...]`.

### Версионирование

`Metadata.Version` — целое. `codec.decode` отказывается принимать `Version` новее известной и выдаёт понятную ошибку. Отсутствующие поля допускаются и означают «не задано» — это позволяет открывать старые JSON новой версией UI.

---

## 9. Валидация

Валидатор разделён на две функции, потому что CLI не имеет доступа к `Spec` (§11).

### `validateStructural(blueprint) -> { errors, warnings }`

Работает без Roblox-специфичных данных. Вызывается и в UI, и в CLI.

| # | Проверка | Ошибка |
|---|---|---|
| 1 | `Id` — непустой, `[A-Za-z0-9_]+` | `Id должен быть идентификатором` |
| 2 | `Cooldown >= 0` | `Cooldown отрицательный` |
| 3 | `AssetSource` ∈ `{"Spec","Stand"}` | `Неизвестный AssetSource` |
| 4 | `StartFrame >= 0`, целое | `Некорректный кадр в блоке <Id>` |
| 5 | `EndFrame > StartFrame` (если задан) | `EndFrame <= StartFrame в блоке <Id>` |
| 6 | `Type` существует в registry | `Неизвестный тип блока: <Type>` |
| 7 | все ключи `Properties` существуют в определении | `Неизвестное свойство <K> у блока <Type>` |
| 8 | все обязательные свойства заданы | `Не задано свойство <K> у блока <Type>` |
| 9 | значения в `Min`/`Max` | `Свойство <K> вне диапазона [<min>, <max>]` |
| 10 | `Slot` ссылается на существующий `AnimationSlot.Id` | `Слот <Id> не найден` |
| 11 | вложенность разрешена для типа | `Блок <Type> не поддерживает вложенность` |
| 12 | ключ в `Children` ∈ `ChildrenSlots` типа | `Слот <K> не существует у блока <Type>` |
| 13 | заполненные `RequiredSlots` присутствуют | `ProcessAttack без заполненных слотов` |
| 14 | `Repeat` заполнен и `EndFrame > StartFrame` | `Repeat без тела` / `Repeat: EndFrame <= StartFrame` |
| 15 | `Branch.Condition` непустой | `Пустое условие` |
| 16 | `CustomCallback.Code` непустой | `Пустой код` |
| 17 | `SetNoCollision.State ~= false` | `NoCollision=false не поддерживается (баг Watchers.luau:68)` |
| 18 | `SetIFrames.Level` ∈ `Enums.IFrames` | `Неизвестный уровень IFrames: <V>` |
| 19 | `ProcessAttack.Stun.Priority` ∈ `Enums.Stun` | `Неизвестный приоритет стана: <V>` |
| 20 | `CreateGrab.BindMode = "RootToRoot"` ⇒ `Offset` задан | `BindMode=RootToRoot без Offset` |

`Block` **не** проверяется на полноту — частичные поля разрешены (§2.7), UI резолвит эффективные значения.

#### Реализация кодов

Кодов `E` меньше, чем строк в таблице: часть проверок объединена, чтобы один дефект не показывался пользователю несколько раз.

| Code | Что покрывает | Решение |
|---|---|---|
| E14 | `Repeat` без тела и `EndFrame <= StartFrame` | одно сообщение со списком причин; `Repeat` исключён из E5 и E13, иначе сломанный `Repeat` давал бы три почти одинаковые ошибки. `EndFrame` по типам разрешён только `Repeat` |
| E18 | проверки 18 и 19, а заодно `BindMode`, `Direction` и любой другой `enum` | общее правило «значение ∈ `Options» вместо трёх почти одинаковых проверок |
| E19 | проверка 20 | без изменений |
| E20 | соответствие значения объявленному типу свойства | добавлена сверх таблицы: мусор в типе иначе проскакивает до эмиттера и падает в сгенерированном файле. Принимает и type-tag после `codec.decode`, и живой Roblox-тип |

Требуемым считается и явно заданное значение, и непустой `Default` — поэтому `Hitbox.Origin` с `Default = CF()` проверку 8 проходит.

W7 срабатывает только когда `Assets.Stand` отсутствует: именно тогда `Punch.luau:37` падает. Если таблица есть, но в ней не хватает ключа, этот ключ уже не найден в E23/E25/E26/E27 — второй код про то же самое не нужен.

### `validateAgainstSpec(blueprint, specData) -> { errors, warnings }`

Требует `Spec.Data.Assets` по `AssetSource`. Вызывается только в `PreviewTab` в игре. Правила живут в `checkAgainstSpec(blueprint, context)`, а эта функция — обёртка: она достаёт `bot-characters.SkillCharacters` и вызывает ядро. Правила 21–23, 25–27 и W7: номер 24 выбыл вместе с `PlayDashAnimation`, поэтому нумерация кодов имеет пропуск и не переименовывается.

| # | Проверка | Ошибка |
|---|---|---|
| 21 | `SkillCharacters` непуст, если есть `Hitbox` | `Hitbox без SkillCharacters: BotService упадёт (Bot.luau:198)` |
| 22 | каждый тег ∈ `BotsCharacters.SkillCharacter` | `Неизвестный тег: <V>` |
| 23 | `PlayAnimation.Slot.AnimationId` ∈ `Assets.Animations` | `Анимация <K> не найдена` |

| 25 | `PlaySound.Sound` ∈ `Assets.Sounds` | `Звук <K> не найдена в Assets` |
| 26 | `EmitParticle.Particle` ∈ `Assets.Models` | `Модель <K> не найдена в Assets` |
| 27 | `EmitFolder.Folder` ∈ `Assets.Models` | `Папка <K> не найдена в Assets` |

### Предупреждения (не блокируют экспорт)

| # | Условие | Причина |
|---|---|---|
| W1 | `Repeat` содержит `ProcessAttack` | `GetFrames:210-217` дублирует тело `count` раз за один Heartbeat — несколько атак за кадр |
| W2 | `Repeat` внутри `Repeat` | Плоская форма `{start, fn, end}` не выражает вложенный диапазон — эмиттер сведёт внутренний `Repeat` к внешнему |
| W3 | `Branch` внутри `ProcessAttack` | Условие выполняется в контексте `andThen`, где нет гарантии порядка относительно `Cast` |
| W4 | `Repeat` шире 30 кадров | Риск пропуска тела при лаг-спайке (`GetFrames:206-207`) |
| W5 | используется `Branch.Condition` или `CustomCallback.Code` | Сырой Luau попадёт в сгенерированный файл дословно |
| W6 | `ProcessAttack` без `Block` | Сработает скрытый дефолт `Hooks/Block.luau:24-29` — стоит показать пользователю осознанно |
| W7 | `AssetSource = "Stand"`, но в `Assets.Stand` нет части нужных ключей | `Punch.luau:37` падает при `Assets.Stand = nil` |

W1-W4 — **предупреждения, а не запреты**: пользователь может осознанно оставить комбинацию. UI показывает их рамкой на таймлайне и списком в футере.

---

## 10. UI

### Компоновка

```
┌───────────────────────────────────────────────────────────────────────────────┐
│ [New] [Import JSON] [Export JSON] [Copy JSON] [Preview] [Clear]   Modified   │
├──────────┬─────────────────────────────────────────┬─────────────────────────┤
│ Palette  │ Timeline                                │ Properties              │
│          │  ruler  0    15    30    45    60       │ ┌─────────────────────┐ │
│ ▸ Query  │  ├─────────────────────────────────      │ │ Damage       [15  ] │ │
│   Hitbox │  │ ▸ Hitbox  ██████████                  │ │ Stun.Duration [0.7 ] │ │
│ ▸ Damage │  │ ▸ ProcessAttack ████████████           │ │ Stun.Priority [Med▼]│ │
│          │  │   ├ OnSuccess                        │ │ Block:               │ │
│ ▸ State  │  │   │  ▸ EmitParticle ██                │ │  ☐ Blockable   [✓]  │ │
│   ×10    │  │   │  ▸ PlaySound    ██                │ │  ☐ PerfectBlk  [ ]  │ │
│ ▸ Combat │  │   ├ OnBlocked                         │ │  ...                 │ │
│ ▸ VFX    │  │   │  ▸ PlaySound    ████              │ └─────────────────────┘ │
│ ▸ Flow   │  │   └ OnArmored                         │ Tabs: [Block]           │
│ ▸ Target │  │ ▸ Wait                               │ Skill: [settings]       │
│          │  └─────────────────────────────────      │ Slots: [animation]      │
│          │  ◀ playhead          ⚠ 2 warnings       │                         │
├──────────┴─────────────────────────────────────────┴─────────────────────────┤
│ Frames: 4   Blocks: 8   Max frame: 60   Errors: 0   Warnings: 2              │
└───────────────────────────────────────────────────────────────────────────────┘
```

### Стандарты визуальных компонентов

| Аспект | Требование |
|---|---|
| Framework | Fusion, как в `src/client/ui/main.luau` |
| Пропсы | `Fusion.Children` со словарём, без ручного `Instance.new` |
| Реактивность | Состояние — в Fusion state; обращений к GUI-инстансам извне нет |
| Тема | Тёмная; один `Theme`-модуль, цвета не хардкодятся в компонентах |
| Шрифт | `Enum.Font.Gotham` (см. оговорку в §12) |
| Скругления | 6px блокам, 4px кнопкам |
| Отступы | кратно 4px; вложенность — 16px на уровень |
| Анимации | 0.15s, `Enum.EasingStyle.Quad` |
| Cleanup | задачи добавляются в scope (`table.insert(scope, connection)`), ручных `:Destroy()` нет |
| Палитра | сортировка по категориям, поиск через существующий `ui/utils/SearchTextMatch.luau` |
| Timeline | drag через `UserInputService`; зум 1-8 px/кадр; горизонтальный `ScrollingFrame` |
| Доступность | зоны клика ≥ 28px, `AutoButtonColor`, `Selectable` на списках |

### Цвета категорий

| Категория | HEX |
|---|---|
| `Query` | `#4FC3F7` |
| `Damage` | `#EF5350` |
| `State` | `#FFA726` |
| `Combat` | `#AB47BC` |
| `VFX` | `#EC407A` |
| `Flow` | `#78909C` |
| `Target` | `#26A69A` |

Цвета хранятся в `registry` как строки (§3), конвертируются в `Color3` в UI.

### Вложенность в таймлайне

Дети рисуются **внутри** плашки родителя, а не на отдельной дорожке:

```
▸ ProcessAttack            ████████████████
  ├ OnSuccess              ░░░░░░░░
  │  ▸ EmitParticle        ░░░
  │  ▸ PlaySound           ░░░░░░
  ├ OnBlocked              ░░░░░░░░░░
  │  ▸ PlaySound           ░░░
  └ OnArmored              (пусто — не рендерится)
```

Свёрнутый узел показывает сводку: `ProcessAttack · 5 children`. Блок с предупреждением (W1-W4) обводится жёлтой рамкой.

### Панель свойств: резолв `Block`

Секция `Block` показывается всегда, с переключателями и **эффективными** значениями. Незаполненное поле отображается серым и подписано значением из `Hooks/Block.luau:24-29`; заполненное — белым. Это делает скрытые дефолты видимыми, не запрещая частичные передачи (§2.7).

Секции `Stun` / `Knockback` / `Angular` / `Ragdoll` сворачиваются и показываются только при заполненном хотя бы одном поле (`BlockProperty.Group`).

### Панель Skill Settings

`DisplayName`, `Id`, `Cooldown`, переключатель `AssetSource` (`Spec` / `Stand`), мультиселект `SkillCharacters` с подсказкой «нужен при наличии Hitbox — иначе боты упадут».

### Экспорт и импорт

Roblox не даёт доступа к clipboard из игры, поэтому:

- `Export JSON` — JSON в `ScrollingFrame` + `TextLabel`, инструкция `Ctrl+A / Ctrl+C`
- `Copy JSON` — `TextBox.Active = true` + фокус, чтобы `Ctrl+A/C` работали сразу
- `Import JSON` — вставка в `TextBox`, разбор через `codec.decode`, валидация, загрузка в редактор
- Плагин (отдельная задача) добавит `plugin:SetClipboard` и запись в файл

### PreviewTab

- **Frames** — pretty-printed `Frames`-таблица, ровно та, что попадёт в файл
- **Scrubber** — перемотка по кадрам; для выбранного кадра показывается список сработавших блоков (симуляция без боя)
- **Code** — итоговый `.luau` через `emitter.emit`

---

## 11. `tools/generate-skill.luau`

Запускается из корня репозитория; можно и из любого каталога — корень берётся от расположения самого CLI:

```
lune run tools/generate-skill.luau path/to/skill.json [--force] [--stdout] [--no-stylua]
```

| Флаг | Смысл |
| --- | --- |
| `-f`, `--force` | перезаписать существующий `src/server/skills/<Id>.luau` |
| `--stdout` | напечатать исходник модуля, не записывая файл и не форматируя |
| `--no-stylua` | не запускать `stylua` после записи |
| `-h`, `--help` | справка по всем флагам |

Результат: `src/server/skills/<Id>.luau` и отчёт на stdout. Код выхода `0` — модуль сгенерирован, `1` — ошибка ввода или валидации.

Требования:
- **не требует Roblox API** — работает поверх JSON-формы; `emitter`, `registry` и `codec` не обращаются к Roblox-типам (§3, §8)
- читает файл и разбирает JSON собственным парсером: `@lune/json` удалён из Lune начиная с 0.9, а `@lune/serde` знает только свой формат, поэтому CLI не зависит от версии рантайма. `null` разворачивается в отсутствующий ключ — так же, как `codec.encode` выбрасывает `nil`
- `Id` → имя файла: коллизия без `--force` это ошибка, символы, недопустимые в имени файла Windows, запрещены
- прогоняет **только** `validateStructural`. Проверки 21–23, 25–27 и W7 требуют `Spec`, недоступного в CLI, — они выполняются только в `PreviewTab` в игре
- ненулевой код выхода при **структурных** ошибках и при `Errors` эмиттера, целевой файл при этом не трогается. Предупреждения W1–W7 не блокируют генерацию, но печатаются
- `stylua` запускается автоматически, если доступен; его отсутствие или ненулевой код выхода не меняют результат. Исходник эмиттера не отформатирован — отступы вложенных секций и разбиение длинных вызовов делает `stylua`, поэтому `--stdout` печатает неформатированный текст
- вложенные секции свойств (`Stun = { Duration = ... }`) и плоские имена (`Stun.Duration`) равнозначны: `validateStructural` разворачивает вложенность в плоские ключи, `emitter` понимает обе формы
- итоговый файл соответствует `stylua.toml`

---

## 12. Порядок реализации

### Фаза 1 — Типы и реестр (4-5 ч)

1. `types.luau` — типы из §4
2. `registry.luau` — 26 блоков из §5, цвета как hex-строки, без Roblox-глобалов на этапе загрузки

Требование к каждому блоку: `Id`, `DisplayName`, `Category`, `Color`, `Properties` с типами и дефолтами, `Cleanup`, `ChildrenSlots`, `RequiredSlots`, `Description`. Дефолты берутся из проверенных источников (§5), а не выдумываются.

Референсы: `src/server/types.luau:65-104`, `Parameters.luau`, `CombatService/init.luau`, `src/shared/effects/*.luau`.

### Фаза 2 — Codec (2-3 ч)

`codec.encode` / `codec.decode` с type-tag (§8), версионирование через `Metadata.Version`.

### Фаза 3 — Validator (2-3 ч)

`validateStructural` (20 проверок) + `validateAgainstSpec` (6) + 7 предупреждений (§9). Обе возвращают `{ errors, warnings }` с путями до блока.

Плюс `checkAgainstSpec(blueprint, context)` — те же правила 21–23, 25–27 и W7, но с уже готовым `specData` / `validTags`. `validateAgainstSpec` остаётся обёрткой над ней: в `lune` `require` не умеет брать модуль по инстансу, поэтому правила не должны быть связаны с тем, кто их достал. Постоянные тесты лежат в `src/shared/packages/SkillConstructor/tests/` и запускаются в обеих средах:

```
lune run src/shared/packages/SkillConstructor/tests/structural.luau
lune run src/shared/packages/SkillConstructor/tests/against-spec.luau
lune run src/shared/packages/SkillConstructor/tests/emitter.luau
```

В Studio те же модули требуются через `require(ReplicatedStorage.shared.packages.SkillConstructor.tests.*)`; в `against-spec` при этом дополнительно проверяется резолв настоящего `bot-characters`.

### Фаза 4 — Emitter (5-6 ч)

1. Обход дерева → плоский список кадров
2. Группировка, сортировка, слияние в callback'и
3. Обязательный preamble `seq.Ctx = { Targets = {} }` на кадре 0
4. `Repeat` → `{start, fn, end}`
5. Статическая генерация `if` для `ProcessAttack` (7 условий)
6. `Branch` → `if/else`
7. Терминатор `{maxFrame}` последним элементом (§2.2)
8. `Cleanup` по пяти стратегиям
9. `NextUuid()` — счётчик вместо `os.clock()`
10. `Hitbox` с `Skill = self` + ручная обрезка `MaxTargets`
11. Stand-преамбула по `AssetSource`
12. `require`-блоки по фактическому использованию
13. Assert-ы инвариантов §2.2 в debug-режиме

### Фаза 5 — CLI (1-2 ч)

`tools/generate-skill.luau` по §11.

### Фаза 6 — UI (11-15 ч) — выполнена

1. Каркас + `Theme` + переключатель вкладок
2. `BlockPalette`
3. `Timeline` + `BlockInstance` (вложенность, drag, resize, рамки предупреждений)
4. `PropertiesPanel` (динамическая форма, группы, резолв `Block`)
5. `SkillSettings` (`AssetSource`, `SkillCharacters`)
6. `AnimationSlotsManager`
7. `PreviewTab` (Frames, scrubber, Code)
8. `Toolbar` (включая `Import JSON`) + `ContextMenu`

Фактические решения, расходящиеся с текстом ТЗ:

| Пункт ТЗ | Как сделано | Почему |
|---|---|---|
| `Fusion.scoped(Fusion.child(...))` | `Fusion.Children` со словарём | В вендоренной Fusion 0.3 ключ `Child` — функция-хелпер, а не спецключ; числовые ключи в `[Children]` она отклоняет (`unrecognisedPropertyKey`) |
| `Enum.Font.GothamSSm` | `Enum.Font.Gotham` | `GothamSSm` — семейство ассетов, а не элемент перечисления, а `Font.new` отклоняется проверкой типов Fusion (`expected a 'EnumItem' type`) |
| `Children: { PlacedBlock }` в §4 | `Children = { слот → массив }` | Так в коде (§5, §7) и в JSON §8; плоский список не позволяет отличить `OnSuccess` от `OnBlocked` |
| `validateAgainstSpec` только в `PreviewTab` | `validator.checkAgainstSpec` + скины из `shared.configs.Skins` | `Spec.Data.Assets` — это скин-конфиг, он лежит в `ReplicatedStorage` и доступен клиенту, поэтому проверки 21–23, 25–27 и W7 выполняются без сервера и без отправки blueprint |

Дополнительно к пунктам выше:

- точка входа — страница `Router` (`SkillConstructor`) плюс клиентская команда
  Cmdr `skillconstructor` (`ClientRun`); вводится **без** префикса `:` — Cmdr
  парсит первый токен как имя команды, поэтому `:skillconstructor` не находится
- команду нельзя объявить модулем в папке Cmdr: `ReplicatedStorage.CmdrClient`
  (вместе с `Commands`/`Types`) создаётся на сервере в рантайме
  (`Cmdr/Initialize.luau`), а клиент сканирует папку один раз — в момент
  `require` `CmdrClient`. Сервер наполняет её позже (`TerminalService`
  переносит `terminal-commands` и встроенные команды), поэтому на клиенте
  не остаётся ни одной команды, включая `echo`. Клиентские команды
  регистрируются явно в `client/services/TerminalService.luau` через
  `Registry:RegisterCommandObject`, а `ui/components/SkillConstructor/Command.luau`
  хранит и определение команды, и обработчик перехода, который отдаёт
  фабрика `ui/main.luau` (роутер живёт внутри неё)
- `Theme.luau` и `Store.luau` добавлены к дереву из §3: `Theme` обязателен по §10,
  `Store` отделён от компонентов, чтобы состояние не передавалось через 10 модулей
- `Store` держит состояние в `Fusion.Value`/`Computed`; blueprint правится на месте,
  а производные значения помечаются ревизией — иначе Fusion считал бы изменение
  отсутствием и правки не отражались бы в таймлайне
- `emitter` экспортирует `maxFrame(json)` и `framesSource(json)`: футер, линейка и
  вкладка `Frames` берут значения оттуда, а не считают вторую реализацию
- `IgnoreGuiInset` у корневого `ScreenGui` заменён на `false`: со `true` Roblox
  сдвигает начало координат GUI вверх на инсет, и верхние панели уезжали за экран
- инстансы не создаются внутри `Computed` (только данные); отрисовку делают
  `ForValues`


### Фаза 7 — Интеграция (2-3 ч)

Сквозной прогон по §17.

---

## 13. Оценка

| Фаза | Часы |
|---|---|
| 1. Типы + реестр (26 блоков) | 4-5 |
| 2. Codec | 2-3 |
| 3. Validator | 2-3 |
| 4. Emitter + компилятор Frames | 5-6 |
| 5. CLI | 1-2 |
| 6. UI | 11-15 |
| 7. Интеграция | 2-3 |
| **Итого** | **27-37** |

---

## 14. Правила написания кода

### Прагмы

`--!strict` и `--!native` **взаимоисключающи**. Правило по образцу из репозитория:

| Тип файла | Прагмы | Пример |
|---|---|---|
| Боевой код на сервере | `--!native` + `--!optimize 2` | `Skill.luau:1-2`, `CombatService/init.luau:1-2`, `Spec.luau:1` |
| Модуль с типами | `--!strict` | `Sequencer/init.luau:1-3` |
| UI-компонент | без прагм | `src/client/ui/*` |
| `tools/*.luau` | без прагм | не требует Roblox |

Сгенерированные скиллы получают `--!native` / `--!optimize 2` — как все существующие скиллы.

### Именование

| Сущность | Стиль | Пример |
|---|---|---|
| Модуль / класс | PascalCase | `SkillConstructor`, `BlockDefinition` |
| Переменная / функция (наш код) | camelCase | `generateCode`, `validateStructural` |
| Константа | UPPER_CASE | `BLOCK_CATEGORIES`, `MAX_FRAME` |
| Тип | PascalCase | `SkillBlueprint`, `PlacedBlock` |
| Поле таблиц-данных | PascalCase | `StartFrame`, `AssetSource` |

**Исключение для сгенерированных скиллов:** локальные переменные пишутся в **PascalCase** (`character`, `RootPart`, `CombatService`, `Anims`, `Sounds`, `Models`) — так написаны все 16 существующих скиллов, и это важнее общего правила `camelCase`. Эмиттер следует стилю целевого файла, а не правилам для нового кода.

### Комментарии

Существующие скиллы **не имеют** файловых хедеров (14 из 16, включая `TEMPLATE.luau`), хотя `create-combat-skill` их требует. Для нового кода конструктора: файловые хедеры не добавляются, doc-комментарии (`---`) пишутся на экспортируемые типы и функции. Комментарии внутри логики не добавляются, если не объясняют инвариант.

### Границы изменений

Никаких правок в:

- `Crane/Packets.luau`
- `SkillService.luau`, `SpecService.luau`
- `CombatService/init.luau` и его хуках
- `components/Character/*`
- `services/BotService/*`
- `shared/effects/*`
- `packages/Sequencer/*`, `packages/Crane/packages/Butler.luau`

Если задача требует правки в core — она выносится за пределы этого ТЗ и согласуется отдельно.

---

## 15. Референсы

Все пути проверены.

### Combat
| Файл | Что берём |
|---|---|
| `src/server/services/CombatService/init.luau` | `Hitbox` `:49`, `Attack` `:128`, `CreateSequence` `:142`, `GetStates` `:150`, `AddArmor` `:179`, `CreateGrab` `:199` |
| `src/server/services/CombatService/Hooks/` | 8 хуков: `IFrames`, `Armor`, `Block`, `Damage`, `Stun`, `Knockback`, `Ragdoll`, `Angular` |
| `src/server/types.luau` | `AttackInfo` `:65`, `HitboxData` `:50`, `GrabData` `:45`, `AttackData` `:106`, `SkillData` `:280` |
| `src/server/Enums.luau` | `IFrames` `:2-7`, `Stun` `:9-14` |
| `src/server/components/Character/Parameters.luau` | все параметры + парсеры |
| `src/server/components/Character/Watchers.luau` | побочные эффекты, баг `NoCollision` `:63-69` |
| `src/server/components/Character/init.luau` | `AddParameter` `:161`, `GetParameter` `:196`, `SetCollisionToPlayers` `:230`, `Ragdoll` `:238` |
| `src/server/services/CollisionService.luau` | `SetCollisionGroup(group, instance)` `:38` — контракт, которого мы сознательно не используем |
| `src/server/services/BotService/Bot.luau` | `Casted` `:196-223`, `table.find(...SkillCharacters...)` `:198`, `Info.Origin` `:201-202`, `SkillCharacters` `:254-256` |
| `src/shared/bot-characters.luau` | допустимые теги `SkillCharacter` |

### Skills
| Файл | Образец |
|---|---|
| `src/server/skills/Punch.luau` | Hitbox с `Skill` `:94`, частичный `Block` `:112-115`, `andThen` `:131`, `seq.Cleaner:Add(function()` `:78-84`, `table.clear(self.AlreadyHit)` `:54`, Stand-ассеты `:37,156` |
| `src/server/skills/Grab.luau` | вложенные sequence, `Bind` c `RootPart` `:127-143`, `seq.Cleaner:Set("GrabObject", ...)` `:127`, `seq.Cleaner:Remove` `:172`, `AttackInfo.Hitbox` `:225` |
| `src/server/skills/Dash.luau` | ручное движение через `BodyVelocity` `:72-79`, `seq.Cleaner:Set("Velocity", ...)` `:81`, IFrames `:60` |
| `src/server/skills/Block.luau`, `Run.luau`, `Barrage.luau`, `StandBarrage.luau`, `Summon.luau` | прочие паттерны |
| `src/server/skills/Undyne/ArcSpearStrike.luau` | `AttackInfo.Hitbox` `:104` |
| `src/server/skills/Standless/Uppercut.luau`, `CircularKick.luau`, `Footrest.luau` | `AttackInfo.Hitbox` |
| `src/server/skills/Gerson/Bonk.luau`, `Undyne/WaitALittleBit.luau` | `AttackInfo.Hitbox` |
| `src/server/skills/TEMPLATE.luau` | скелет (**закомментированные** примеры, не рабочий код) |

### Sequencer / Butler
| Файл | Что берём |
|---|---|
| `src/shared/packages/Sequencer/init.luau` | `GetFrames` `:192`, формы кадров `:157-159`, терминатор `:256-259`, проверка конца `:266`, `Stop` `:274`, `Destroy` `:325` |
| `src/shared/packages/Sequencer/Butler.luau` | авто-детект методов `:192-219` — **не знает `Cleanup`** |
| `src/shared/packages/Crane/packages/Buttler.luau` | `Add` `:280`, `Set` `:314`, `Remove`, `Scope`, `OnClean` `:670` |
| `src/shared/packages/Crane/Packets.luau` | **справочно** — схема паттернов (не меняется) |

### VFX
| Файл | Сигнатура |
|---|---|
| `src/shared/effects/Animation.luau` | `onStart(character, {Animation, Speed})`, `onStop(character, {Animation, FadeTime})` |
| `src/shared/effects/Sound.luau` | `onStart(Origin, {Sound, Volume, MaxDistance, MinDistance})` |
| `src/shared/effects/EmitParticle.luau` | `{UUID?, Particle, Origin, Offset?, UseForge?}`; `UUID` нужен только для `onStop` `:88` |
| `src/shared/effects/EmitFolder.luau` | `onStart(character, effectsFolder, uuid?)`, `onStop(character, uuid)` |
| `src/shared/effects/Highlight.luau` | `{FillColor, OutlineColor, FillTransparency, OutlineTransparency, Lifetime, Tween, UUID, Adornee}` |
| `src/shared/effects/Dash.luau` | `onStart(Character, {SpecId, SkinId}, Normal)` |
| `src/shared/effects/Hitbox.luau` | `onStart(Origin, Size)` — только для `Hitbox.Debug` |
| `src/shared/effects/Ragdoll.luau` | `onStart/onStop(character)` |
| `src/server/services/VFXService.luau` | `StartEffect` `:19` / `StopEffect` `:42` — **возвращают `nil`** |

### UI
| Файл | Образец |
|---|---|
| `src/client/ui/main.luau` | `ScreenGui`, `Fusion.scoped`, `Fusion.Children` |
| `src/client/ui/views/RegionView.luau` | компонент-экран со слоями |
| `src/client/ui/views/LoadingScreen.luau` | полноэкранный layout, анимации |
| `src/client/ui/utils/Router/init.luau` | переключение экранов, `OnEnter`/`OnLeave`, `Buttler` |
| `src/client/ui/utils/Button.luau` | переиспользуемый контрол |
| `src/client/ui/utils/Shadow.luau` | декор |
| `src/client/ui/utils/MixedText.luau` | работа с текстом |
| `src/client/ui/utils/SearchTextMatch.luau` | поиск по имени в палитре |
| `src/client/ui/PAC.storybook.luau` | изоляция компонентов в стори |
| `src/shared/packages/Fusion/init.luau` | API |

> `src/client/ui/components/PlayerHUD.luau` — **не образец**: 36-строчный плейсхолдер с `Visible = false`.

### Прочее
| Файл | Зачем |
|---|---|
| `default.project.json` | маппинг: `src/server` → `ServerScriptService.server`, `src/client` → `StarterPlayer.StarterPlayerScripts.client`, `src/shared` → `ReplicatedStorage.shared`. `tools/` в дерево **не входит** — сознательно, CLI не должен попадать в билд |
| `src/server/Configuration/SkillsFolder.model.json` | `ObjectValue` с `Rojo_Target_Value` — см. §17 |
| `src/shared/configs/Specs.luau` | бинды скиллов — см. §17 |
| `src/server/specs/Standless.luau` | пример модуля спеки со списком `Skills` |
| `stylua.toml` | форматирование |
| `CODING_STANDARDS.md`, `PROJECT_STRUCTURE.md` | соглашения |
| `AGENTS.md` | порядок работы в репозитории |
| `.opencode/skills/create-combat-skill/SKILL.md` | формат описания скилла (учитывать, что хедеры не соблюдаются) |

---

## 16. Критерии готовности

1. Скилл, собранный в UI, экспортируется в JSON; этот же JSON импортируется обратно без потерь
2. `tools/generate-skill.luau` на чистом Luau-интерпретаторе (lune) генерирует `.luau` без ошибок и без Roblox API
3. Сгенерированный файл проходит `validateStructural` в CLI и открывается как `ModuleScript` в `SkillsFolder`
4. Вызов через `SkillService:CreateSkill` проходит `Skill:Validate()` и отрабатывает sequence
5. Эмиттер гарантирует инварианты §2.2: **последний элемент `Frames` — терминатор `{maxFrame}`, стоящий последним**, а все вызовы тела в этом Heartbeat отрабатывают до `Stop()`
6. Sequence корректно сбрасывает per-cast состояние: `seq.Ctx` пуст на каждом `Play()`, две последовательные активации не делят `Targets`
7. Все ресурсы освобождаются при `Interrupt()` — визуально подтверждено отсутствие залипающих эффектов и параметров
8. `AddArmor` не даёт предупреждения Butler (чистится через `Janitor:Clean()`, §2.4)
9. `Hitbox` в выводе содержит `Skill = self`; бот реагирует на сгенерированный скилл, и позиция хитбокса у бота совпадает с `Info.Origin`
10. `validateStructural` ловит все 20 нарушений из §9; `validateAgainstSpec` — все 7
11. `CustomCallback` и `Branch.Condition` доходят до `.luau` дословно и помечены предупреждением W5
12. Ни один файл в `registry`, `codec`, `validator`, `emitter` не обращается к Roblox-типам при загрузке

---

## 17. Цепочка деплоя

Шаги 2-4 существующи в проекте и обязательны — без них скилл не загрузится, даже если файл сгенерирован.

| # | Шаг | Где |
|---|---|---|
| 1 | Сгенерировать файл | `lune run tools/generate-skill.luau skill.json` → `src/server/skills/<Id>.luau` |
| 2 | Убедиться, что `Configuration.SkillsFolder.Value` указывает на папку скиллов | `SkillService.luau:9,52-56` берёт `Configuration.SkillsFolder.Value`. Это `ObjectValue`; в репозитории — `src/server/Configuration/SkillsFolder.model.json` с атрибутом `Rojo_Target_Value`. Должен резолвиться в `ServerScriptService.server.skills` (куда Rojo мапит `src/server`). Если в подключённом Studio `Value == nil` — это предварительное условие, **не следствие конструктора** |
| 3 | Записать скилл в модуль спеки | `src/server/specs/<Spec>.luau`, поле `Skills`: `["<Id>"] = "~/skills/<Id>"` (образец — `Standless.luau:10-20`) |
| 4 | Записать бинд | `src/shared/configs/Specs.luau`, поле `Binds`. Без него `SpecService:70-74` сделает `skill:SetBind(nil)` и скилл нельзя вызвать |
| 5 | Rojo sync и проверка в бою | `Skill:Validate()` (`Skill.luau:100-107`) должен проходить, скилл активируется биндом |

`.meta.json` для новых `.luau`-файлов **не нужны** — Rojo создаёт `ModuleScript` без них. `Configuration/*.model.json` добавлять не требуется: `SkillsFolder` и `SpecsFolder` уже определены.

