# Контракт и жизненный цикл скилла

Скилл — модуль в `src/server/skills/`, возвращающий таблицу, приблизительно соответствующую `types.SkillData`. Скиллы намеренно **не жёсткие**: каждый определяет свои приватные поля.

## Контракт

| Поле | Обязательно | Примечание |
|---|---|---|
| `DisplayName` | Да | Человекочитаемое имя; публикуется в `Skill:Init`. |
| `Id` | Устанавливает `SkillService` | Равен имени файла модуля и ключу в `Skills` спека. |
| `Tag` | Нет | Например, `"OnlyForStand"` — включает/выключает скиллы через `Spec:SetEnableSkills`. |
| `BaseSpec` | Нет | id спека-фолбэка для поиска ассетов. |
| `Cooldown` | Да в строгом типе, но проверяется в рантайме | Секунды до повторного применения; умножается на `CooldownMultiplier`. |
| `AttackInfo` | Да в строгом типе, но проверяется в рантайме | См. [[AttackInfo and AttackData (RU)]]. |
| `SkillCharacters` | Нет | Типизированные теги ботов из `src/shared/bot-characters.luau`: `"Hit"`, `"Stun"`, `"Blockable"`, `"PerfectBlock"`, ... |
| `onInit` | Нет | Вызывается из `Skill:Init()` при добавлении в спек; доступны `self.Character`, `self.Spec`, сервисы. |
| `onDestroy` | Нет | Вызывается при уничтожении скилла перед очисткой `Cleaner`. |
| `Activate` | Нет | Вызывается при срабатывании после проверки `Skill:Validate`. |
| `Interrupt` | Нет | Вызывается, только пока `Active`, обычно через подключение `CombatService.Interrupted`, созданное `Skill:Init`. |

Всё остальное — приватные данные: `ComboCooldown`, `DashProperties`, `PreBarrageInfo`, `Throw`, а также `Checks` (таблица, которую читает `Skill:Validate`). `SkillCharacters` — перечисление, а не свободный текст: предпочитайте канонические `"PerfectBlock"` и `"BlockBreak"`, псевдонимы `PerfectBlockable` / `BlockBreaker` — устаревшие. `OnlyForStand` — значение `Tag`, а не SkillCharacter. Ищите ближайший существующий аналог, а не навязывайте шаблон.

На практике `Cooldown` необязателен: скиллы, запускающие кулдаун вручную — `MarkedKnives` при трате заряда `KnivesCharge` и Distant Slam после нахождения помеченной цели — объявляют `Cooldown = 0` и сами вызывают `self:SetCooldown(...)`. Другие необязательные поля данных скиллов, используемые сейчас: `AimRequired`, `UseCooldown`, `SearchRadius`, `Hitbox`, `BarrageInfo`, `PostBarrageInfo`, `ProjectileData`. Это типизированные метаданные, которые читают сами скиллы; движок их не проверяет. Дискретные заряды ножей — обычная запись в `shared/configs/Charges.luau`; тратятся они через `CombatService:GetCharge/ConsumeCharge`, а не через отдельную систему патронов.

## Заголовок файла

Каждый модуль скилла начинается с блока комментария с именем скилла и секцией `ASSETS`, перечисляющей все анимации, звуки, модели и статы, которые он использует. Это позволяет проверить конфиг скина спека по реальным требованиям.

## Жизненный цикл

- `Skill.new` создаёт `Cleaner = Crane.Buttler.new()`; поля `Janitor` у скилла нет. `Spec:AddSkill` вызывает `skill:Init()`, тот — `Data.onInit(self)` и подключает `CombatService.Interrupted` только при наличии `Interrupt`.
- `onInit`: получить сервисы через `Crane:GetService`, кэшировать ассеты через `self:GetAsset(...)`, создать секвенс в `self.Cleaner`, инициализировать состояние.
- `Activate`: `Skill.Activate` проверяет `Active`, ставит `Holding`, добавляет параметр `CastingSkill` на всё время каста, вызывает `Data.Activate` под `xpcall`, затем применяет кулдаун; внутри — проиграть секвенс ([[Sequencer (RU)]]) или использовать promise, привязанный к сигналам (паттерн `Block`).
- `Deactivate` посылает `Deactivated` только если `Holding`; `Activate` этого сигнала не посылает. Для hold-to-cast используйте `self.Deactivated:Once(...)`.
- `Interrupt`: вызывается, только пока `Active`; останавливает секвенсы и эффекты, освобождает параметры. Своё подключение к `CombatService.Interrupted` обычно не нужно.
- `Destroy`: вызывает `Data.onDestroy`, затем уничтожает `Cleaner`.
- `GetAsset` / `TryGetAsset`: пути через `/` в `Spec.Data.Assets`; фолбэк идёт в ассеты `BaseSpec` через `SpecService:GetSpecData`. `TryGetAsset` молча возвращает `nil`, `GetAsset` предупреждает и прерывает каст. `None` — просто имя скина по умолчанию, а не фолбэк для каждого пути.
- `Checks` задаются на данных скилла, чтобы отключить проверки по умолчанию: `NoSkillCast`, `Stun`, `Ragdoll`, `Dead`, `IsGrounded`, `Restand`, кулдаун.

## Паттерны

| Цель | Пример |
|---|---|
| Минимальный переключатель | `src/server/skills/Run.luau` |
| Один удар с секвенсом | `src/server/skills/TEMPLATE.luau`, `Undyne/ArcSpearStrike.luau` |
| Комбо | `src/server/skills/Punch.luau` |
| Защита / блок | `src/server/skills/Block.luau` |
| Передвижение | `src/server/skills/Dash.luau` |
| Многофазная атака | `src/server/skills/Barrage.luau` |
| Захват / бросок | `src/server/skills/Grab.luau` |
| Скилл только для стэнда | `StandBarrage.luau`, `StarStrike.luau` (`Tag = "OnlyForStand"`) |

## Регистрация

1. `src/server/skills/<Name>.luau` или `src/server/skills/<Spec>/<Name>.luau`. Имя файла = `Id` = ключ в `Skills`; строки `~/skills/...` и `@Specs/...` — только соглашение об именах.
2. Ключ в таблице `Skills` спека. См. [[Spec and SubSpec (RU)]].
3. Обязательный бинд в `src/shared/configs/Specs.luau`: без него скилл пропускается с предупреждением. Все бинды — hold-to-cast, поля `Hold` не существует. См. [[Input and BindService (RU)]].

Связанные: [[Create a combat skill (RU)]], [[Sequencer (RU)]], [[Combat pipeline (RU)]]. Оригинал: [[Skill contract and lifecycle]].
