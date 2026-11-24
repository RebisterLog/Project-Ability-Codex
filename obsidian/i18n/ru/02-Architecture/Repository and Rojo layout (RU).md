# Строение репозитория и Rojo

## Корень

Головные скрипты проверки удалены из инструментов; см. [[Formatting and inspection (RU)]].

| Путь | Роль |
|---|---|
| `src/` | Весь исходный Luau первой стороны. |
| `tools/` | Lune-скрипты проверок, форматирования, генерации и инспекции. |
| `obsidian/` | Это хранилище документации. |
| `AGENTS.md` | Краткие правила для агентов и маршрут в хранилище. |
| `default.project.json` | Определение проекта Rojo. |
| `.luaurc`, `stylua.toml`, `.gitignore` | Псевдонимы, конфигурация форматтера, правила игнорирования. |
| `README.md`, `LICENSE` | Точка входа и лицензия. |

## Соответствие Rojo

| Источник | Контейнер Roblox |
|---|---|
| `src/shared` | `ReplicatedStorage.shared` |
| `src/server` | `ServerScriptService.server` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.client` |

Один и тот же путь модуля требуется со всех трёх сторон через эти контейнеры. Не хардкодьте абсолютный путь `game`, если работает путь относительно Rojo.

## `src/` кратко

- `src/server/`: `services/`, `components/`, `combat-classes/` (`Skill`, `Spec`, `Hook`, `Projectile`, заряды), `skills/`, `specs/`, `player-modules/`, `quests/`, `terminal-commands/`, `Configuration/`, `types.luau`, `Enums.luau`.
- `src/client/`: `services/`, `components/`, `controls/`, `ui/` (разделение Component/View, `Router`, stories), `player-modules/`, `skills/`, `types.luau`.
- `src/shared/`: `packages/` (вендор, только для чтения), `configs/`, `schemas/`, `effects/`, `combat/`, `components/`.

## Правила

1. Пакеты в `src/shared/packages/` доступны только для чтения и пропускаются форматтером.
2. `src/shared` не может предполагать одну машину: код может выполняться и на сервере, и на клиенте.
3. Публичные типы лежат в `src/server/types.luau`, `src/client/types.luau` и `src/shared/schemas/`. См. [[Types index (RU)]].
4. Сборка: `rojo build -o PAC.rbxlx`, сервер: `rojo serve`.

Связанные: [[Runtime boundaries (RU)]], [[Services and dependencies (RU)]], [[Source index (RU)]]. Оригинал: [[Repository and Rojo layout]].
