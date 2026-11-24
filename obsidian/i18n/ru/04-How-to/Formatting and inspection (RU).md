# Форматирование и инспекция

В репозитории больше нет головного тестового раннера и гейтов качества. Проверка — это ручной тест в Studio плюс три небольших Lune-инструмента.

## Текущие инструменты

| Инструмент | Команда | Назначение |
|---|---|---|
| Context | `lune run tools/context.luau` (`--json`) | Снимок: ветка/head, изменённые файлы, количество исходников/скиллов/спеков, наличие `lune`, `stylua`, `rojo`. |
| Format | `lune run tools/format.luau` (`--fix`, `--src`, `--exclude`) | Проверка или применение форматирования StyLua. |
| Impact | `lune run tools/impact.luau <path-or-identifier>` (`--json`) | Радиус поражения: файлы, ссылающиеся на путь или идентификатор. |

`tools/Toolchain.luau` — общая библиотека этих скриптов, не команда. Она ищет бинарники через `PAC_TOOLS_DIR`, каталог рядом с `lune`, `<root>/.tools` и `PATH`, а также задаёт список вендорных путей, которые никогда не форматируются и не сканируются.

## Форматирование

```bash
lune run tools/format.luau                      # проверить tools/
lune run tools/format.luau --fix                # отформатировать tools/
lune run tools/format.luau --fix --src          # tools/ и src/
lune run tools/format.luau --exclude a.luau,b/  # дополнительные исключения
```

`stylua.toml` запрашивает Unix-переводы строк, но Windows-копия приходит с CRLF. Скрипт группирует файлы по текущим переводам и запускает StyLua для каждой группы, поэтому `--fix` не переписывает переводы строк целиком. Вендорные пакеты в `src/shared/packages/` пропускаются; `Signal.luau` исключён по умолчанию. Если StyLua не найден, скрипт печатает подсказку, а не падает.

## Инспекция

```bash
lune run tools/context.luau
lune run tools/impact.luau CombatService
lune run tools/impact.luau src/shared/combat/Knockback.luau --json
```

Используйте `impact` перед изменением часто используемого модуля; `context` — для быстрой ориентации в незнакомой рабочей копии.

## Задачи редактора

`.zed/tasks.json` содержит три задачи: `Format` (команда `--fix --src` выше), `Rojo: Build` и `Rojo: Server`.

## Процесс проверки

1. Выполните `rojo build -o PAC.rbxlx` или используйте активный сервер Rojo.
2. Запустите проверку/исправление форматирования.
3. С помощью `impact` посмотрите, что затронет изменение.
4. Вручную проверьте поведение в Studio. Автоматического набора тестов нет.

Связанные: [[Gotchas (RU)]], [[Templates and generators (RU)]], [[Repository and Rojo layout (RU)]]. Оригинал: [[Formatting and inspection]].
