# Player modules

Per-player modules are plain `ModuleScript`s that are deep-cloned for each player and injected with context by the `Player` component. They are the preferred place for player-scoped behaviour that is not a full service.

| | Server | Client |
|---|---|---|
| Folder | `src/server/player-modules/` | `src/client/player-modules/` |
| Host | `src/server/components/Player.luau` | `src/client/components/Player.luau` |
| Injected | `Name`, `player`, `playerProxy` | `Name`, `player`, `playerProxy`, `gameProxy`, `Cleaner` |
| Lifecycle | `onInit` → `onStart` | `onInit` → `onStart` → `onCharacter` → `onDestroy` |
| Init trigger | after document data loads | after both proxies arrive (`PlayerService.onInit`) |
| Public type | `PlayerModule` in `src/server/types.luau` | `ClientPlayerModule` in `src/client/types.luau` |

## Rules

1. All callbacks are optional and wrapped in `pcall` by the host; one faulty module cannot break the rest.
2. Use `self.Cleaner` for connections, tasks and spawned instances.
3. On the client, call `self.Cleaner:Clean()` at the start of `onCharacter` to release resources from the previous character.
4. Read another module with `Player:GetModule(name)`.

## Minimal shape

```luau
local Module = {}

function Module:onInit() end
function Module:onStart() end
function Module:onCharacter(character: Model) end
function Module:onDestroy() end

return Module
```

Related: [[Player and character lifecycle]], [[Data schemas and Proxy]], [[Create a service or component]].
