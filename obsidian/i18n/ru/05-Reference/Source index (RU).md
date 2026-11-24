# Указатель исходников

Кураторская карта того, где что находится. Пути относительно корня репозитория.

## Сервер

| Область | Путь |
|---|---|
| Сервис боя и хуки | `src/server/services/CombatService/` |
| Классы `Skill`, `Spec`, `Hook`, `Projectile` | `src/server/combat-classes/` |
| Скиллы | `src/server/skills/` (общие в корне, уникальные в папках персонажей) |
| Спеки | `src/server/specs/` |
| Компоненты | `src/server/components/` |
| Player-модули | `src/server/player-modules/` |
| Квесты | `src/server/quests/` |
| AI ботов | `src/server/services/BotService/` |
| Терминальные команды/хуки | `src/server/terminal-commands/`, `src/server/terminal-hooks/` |
| Публичные типы | `src/server/types.luau` |
| Перечисления | `src/server/Enums.luau` |

## Клиент

| Область | Путь |
|---|---|
| Сервисы | `src/client/services/` |
| Компоненты | `src/client/components/` |
| Ввод | `src/client/controls/` |
| UI | `src/client/ui/` (`components/`, `views/`, `utils/Router`, `stories/`, `main.luau`) |
| Player-модули | `src/client/player-modules/` |
| Публичные типы | `src/client/types.luau` |

## Общий код

| Область | Путь |
|---|---|
| Конфиги | `src/shared/configs/` (`Specs.luau`, `Skins/`, `Quests/`, `Bots/`, `BotSpawners/`) |
| Схемы | `src/shared/schemas/` |
| Боевые хелперы | `src/shared/combat/` (`Block`, `ChargeState`, `Knockback`) |
| Эффекты | `src/shared/effects/` |
| Компоненты | `src/shared/components/Stand/` |
| Вендорные пакеты | `src/shared/packages/` (только чтение) |

## Инструменты

`tools/`, `default.project.json`, `.luaurc`, `stylua.toml`, `.gitignore`.

Связанные: [[Repository and Rojo layout (RU)]], [[Types index (RU)]], [[Developer map (RU)]]. Оригинал: [[Source index]].
