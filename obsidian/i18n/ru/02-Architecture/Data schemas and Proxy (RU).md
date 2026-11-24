# Схемы данных и Proxy

## Схемы

| Схема | Роль |
|---|---|
| `GameData` | Форма глобального документа игры. |
| `PlayerData` | `PlayerDynamicData` + `PlayerSaveData`. |
| `PlayerDynamicData` | Состояние рантайма: слот спека, параметры персонажа, текущие спеки. |
| `PlayerSaveData` | Сохраняемое состояние: спекы и прогресс. |

Публичные типы экспортируются из `src/server/types.luau`, `src/client/types.luau` и `src/shared/schemas/`. См. [[Types index (RU)]].

## Паттерн Proxy

Proxy — реактивное дерево состояния для репликации состояния скиллов/спеков без отправки полных снимков.

```luau
self.Proxy = Proxy({ Skills = {} })
self.Proxy:Patch({
    { Name = "SetDictionary", Path = { "Skills" }, Args = { skillId, skill.Proxy() } }
})

local cleanup = skill.Proxy:Subscribe("AnyChange", { "Parameters" },
    function(newValue, oldValue, instruction) end)

cleanup() -- отписка
local state = self.Proxy()
```

## Правила, которые стоит запомнить

- `AnyChange` срабатывает, когда подписанный путь — **префикс** изменённого пути. Замена родителя не уведомляет подписчиков глубже этого родителя.
- Wildcard: `*` — один сегмент, `**` — один или более.
- Точные подписки — O(1); `AnyChange` стоит по одному поиску на сегмент; паттерны сканируют список паттернов.
- Патч, который ничего не меняет, не вызывает колбэк и не передаётся в `OnPatch`.
- Бросающий исключение слушатель сообщает через `warn` и не останавливает остальную пачку.
- Всегда вызывайте возвращённую функцию очистки, когда потребитель удаляется.

Связанные: [[Runtime boundaries (RU)]], [[Input and BindService (RU)]], [[Gotchas (RU)]]. Оригинал: [[Data schemas and Proxy]].
