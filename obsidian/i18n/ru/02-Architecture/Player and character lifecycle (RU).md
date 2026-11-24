# Жизненный цикл игрока и персонажа

## От входа к управляемому персонажу

| Этап | Где | Что происходит |
|---|---|---|
| 1. Вход | сервер `PlayersService` / `GameDataService` | Загружается документ данных. |
| 2. Компонент игрока | `src/server/components/Player.luau` | Доступно состояние игрока; `InitModules()` запускает серверные player-модули. |
| 3. Создание персонажа | `src/server/player-modules/CharacterAdder.luau` | Модель и компонент `Character` прикрепляются. |
| 4. Выбор спека | `src/server/components/Character/init.luau` → `SetSpec` | Вызывается `SpecService:CreateSpec`. |
| 5. Сборка спека | `src/server/services/SpecService.luau` | Слияние конфига, модуля и скина; `SkillService:CreateSkill` для каждого скилла; `spec:AddSkill`; бинды. |
| 6. Инициализация спека | `src/server/combat-classes/Spec.luau` | Анимации `Idle`, `Walk`, `Run` становятся атрибутами; вызывается `Data.onInit`. |
| 7. Инициализация скилла | `src/server/combat-classes/Skill.luau` | Вызывается `onInit`, подключается `Interrupt` к `CombatService.Interrupted`. |
| 8. Настройка клиента | `src/client/components/Player.luau` | После прокси `PlayerService.onInit` запускает клиентские модули; `onCharacter` — при спавне/респавне. |

## Очистка и респавн

- Player-модули получают `Cleaner` (Crane Buttler); там освобождаются соединения и созданные объекты. См. [[Player modules (RU)]].
- Скиллы владеют `Janitor`, секвенсы — `seq.Cleaner`. `Interrupt` должен остановить секвенсы и эффекты. См. [[Skill contract and lifecycle (RU)]].
- После нескольких респавнов на одной модели может быть несколько компонентов `Character`. Не предполагайте один. См. [[Gotchas (RU)]].

Связанные: [[Spec and SubSpec (RU)]], [[Data schemas and Proxy (RU)]], [[Input and BindService (RU)]]. Оригинал: [[Player and character lifecycle]].
