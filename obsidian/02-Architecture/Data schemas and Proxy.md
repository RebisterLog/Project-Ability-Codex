# Data schemas and Proxy

## Schemas

| Schema | Role |
|---|---|
| `GameData` | Global game document shape. |
| `PlayerData` | `PlayerDynamicData` combined with `PlayerSaveData`. |
| `PlayerDynamicData` | Runtime state: spec slot, character parameters, current spec/subspec. |
| `PlayerSaveData` | Persistent state: saved specs and progression. |

Public types are exported from `src/server/types.luau`, `src/client/types.luau` and `src/shared/schemas/`. See [[Types index]].

## Proxy pattern

Proxy is a reactive state tree used to replicate skill/spec state to clients without sending whole snapshots.

```luau
self.Proxy = Proxy({ Skills = {} })
self.Proxy:Patch({
    { Name = "SetDictionary", Path = { "Skills" }, Args = { skillId, skill.Proxy() } }
})

local cleanup = skill.Proxy:Subscribe("AnyChange", { "Parameters" },
    function(newValue, oldValue, instruction) end)

cleanup() -- unsubscribe
local state = self.Proxy()
```

## Rules worth memorising

- `AnyChange` fires when the subscribed path is a **prefix** of the changed path. Replacing a parent does not notify subscribers deeper than that parent.
- Wildcards: `*` matches one path segment, `**` matches one or more.
- Exact subscriptions are O(1); `AnyChange` costs one lookup per path segment; pattern subscriptions scan the pattern list.
- A patch that changes nothing produces no callback and is not forwarded to `OnPatch`.
- A throwing listener is reported with `warn` and does not stop the rest of the batch.
- Always call the returned cleanup function when the consumer goes away.

Related: [[Runtime boundaries]], [[Input and BindService]], [[Gotchas]].
