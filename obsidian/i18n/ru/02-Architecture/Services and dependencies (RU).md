# Сервисы и зависимости

Сервисы — синглтоны Crane, создаваемые через `Crane:CreateService({ Name = "..." })` и получаемые через `Crane:GetService("Name")`. Жизненный цикл: `onInit`, затем `onStart`.

## Серверные сервисы

| Сервис | Ответственность |
|---|---|
| `CombatService` | `Hitbox`, `Attack`, `CreateSequence`, `CreateGrab`, `AddArmor`, `GetStates`; сигналы `Casted`, `Attacked`, `Interrupted`; конвейер хуков. |
| `SkillService` | Загрузка и создание скиллов, обработка `StartSkill` / `StopSkill`, кулдауны. |
| `SpecService` | Сборка спеков из конфига и модуля, назначение биндов и скинов. |
| `ConfigsService` | Загрузка `Specs`, `Skins`, ботов, квестов и других конфигов. |
| `PlayersService` | Реестр игроков и состояние в их рамках. |
| `CollisionService` | Регистрация и назначение групп коллизий. |
| `VFXService` | `StartEffect` / `StopEffect` для Animation, Sound, Particle, Highlight, Hitbox, Ragdoll. |
| `GameDataService` | Сохранение документов игрока и игры. |
| `QuestService` | Жизненный цикл и прогресс квестов. |
| `BotService`, `BotSpawnService` | Управление NPC и спавн. См. [[Bot combat AI (RU)]]. |
| `StandService` | Состояние стендов. |
| `TerminalService` | Команды и хуки консоли разработчика. |
| `PathUtil` | Помощники поиска пути. |

## Схема зависимостей

```
SkillService  -> SpecService, PathUtil
SpecService   -> ConfigsService, SkillService
CombatService -> VFXService
QuestService  -> GameDataService, ConfigsService
BotService    -> CombatService, PathUtil, ConfigsService
```

Зависимости получаются по имени через Crane, а не передаются в конструктор. Порядок `onInit` важен, если сервис нужен во время `onStart` другого сервиса.

## Клиентские сервисы

`BindService` (ввод → пакеты), `PlayerService` (локальный игрок и прокси), `TargetLockService`, `UIService`, `VFXService`, `TerminalService`, `BridgeService` (только Studio).

Связанные: [[Player and character lifecycle (RU)]], [[Combat pipeline (RU)]], [[Create a service or component (RU)]]. Оригинал: [[Services and dependencies]].
