# Player-модули

Player-модули — обычные `ModuleScript`, которые глубоко клонируются для каждого игрока и получают контекст от компонента `Player`. Это предпочтительное место для привязанное к игроку поведение, которое не является полноценным сервисом.

| | Сервер | Клиент |
|---|---|---|
| Папка | `src/server/player-modules/` | `src/client/player-modules/` |
| Хост | `src/server/components/Player.luau` | `src/client/components/Player.luau` |
| Внедряется | `Name`, `player`, `playerProxy` | `Name`, `player`, `playerProxy`, `gameProxy`, `Cleaner` |
| Жизненный цикл | `onInit` → `onStart` | `onInit` → `onStart` → `onCharacter` → `onDestroy` |
| Триггер инициализации | после загрузки документа | после прихода обоих прокси (`PlayerService.onInit`) |
| Публичный тип | `PlayerModule` в `src/server/types.luau` | `ClientPlayerModule` в `src/client/types.luau` |

## Правила

1. Все колбэки необязательны и обёрнуты хостом в `pcall`; один неисправный модуль не ломает остальные.
2. Используйте `self.Cleaner` для соединений, задач и созданных объектов.
3. На клиенте вызывайте `self.Cleaner:Clean()` в начале `onCharacter`, чтобы освободить ресурсы предыдущего персонажа.
4. Другой модуль читается через `Player:GetModule(name)`.

## Минимальная форма

```luau
local Module = {}

function Module:onInit() end
function Module:onStart() end
function Module:onCharacter(character: Model) end
function Module:onDestroy() end

return Module
```

Связанные: [[Player and character lifecycle (RU)]], [[Data schemas and Proxy (RU)]], [[Create a service or component (RU)]]. Оригинал: [[Player modules]].
