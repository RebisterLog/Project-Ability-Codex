# Bridge (Studio only)

A runtime control surface for Studio playtests. It is **not** part of the published game.

## Security

- Server: `ServerScriptService.Bridge`; client: `ReplicatedStorage.Bridge`.
- Both services check `RunService:IsStudio()` before creating instances; operations re-check at execution time.
- Do not add a path that bypasses these checks.

## Round trip

```luau
-- request
{ Id = 123, Op = "crane.services", Args = {} }
-- response on the matching channel
{ Id = 123, Ok = true, Value = ... }
-- or
{ Id = 123, Ok = false, Error = "..." }
```

`Id` correlates a request with its response. `bridge.help` prints the operation catalog.

## Operation groups

| Group | Examples |
|---|---|
| `bridge` | help, ping, catalog |
| `crane` | services, components, signals, packets, proxies |
| `instances` | find, get properties, descendants |
| `game state` | players, characters, spec state |

## Encoding limits

Depth 6; 500 nodes; 200 keys per table; 4096 characters per string; 150 properties per Instance. Arrays come back with string keys plus a `Count` field.

## Gotchas

- Values are encoded, not passed by reference; mutations do not affect the live instance unless an operation explicitly applies them.
- Large trees hit the node limit; query narrowly.
- Some query operations report engine-side quirks; keep requests small and deterministic.

Related: [[Services and dependencies]], [[Gotchas]], [[Runtime boundaries]].
