# PAC - AI Agent Guidance (compact)

Start here: `docs/AI_CONTEXT.md` (Rojo paths, naming, pragmas, commands, gotchas). Full long-form docs remain in `docs/`.

## Load skill by task
- Combat skill module → skill `create-combat-skill` (also `pac-combat`)
- Spec/skin/spec config → skill `create-spec`
- UI element → skill `create-ui-element`
- Luau/idioms/conventions → skill `pac-luau`
- Crane (services/components/signals/packets) → skill `pac-crane`
- Attack/Sequencer/VFX/params → skill `pac-combat`
- Studio Bridge → skill `pac-bridge`
- Performance/Proxy → skill `pac-performance`

## Runtime Bridge (Studio only)
`src/shared/packages/Bridge/`, `src/server/services/BridgeService.luau`, `src/client/services/BridgeService.luau`.
Server: `ServerScriptService.Bridge`; Client: `ReplicatedStorage.Bridge`.
Envelope `{ Id, Op, Args }`; read matching `{ Id, Ok, Value|Error }`. `bridge.help` for catalog. See `docs/BRIDGE.md`, skill `pac-bridge`. Studio only; never reachable in published game.

## Editor / formatting
Zed config `.zed/settings.json` committed. Format on save goes through lunaut's built-in StyLua formatting (`lunaut.format.enabled`); `stylua.toml` holds the style. Line endings `detect` (mixed CRLF/LF; do not force). Vendored read-only. Whole-project pass that preserves the mixed endings:
```
lune run tools/format.luau --fix --src
```

## Project standards & structure
- `docs/CODING_STANDARDS.md` — full conventions, architecture, patterns.
- `docs/PROJECT_STRUCTURE.md` — combat components & server impl.
- `docs/GOTCHAS.md` — known traps (read before risky edits).

## Project structure (Rojo)
- Shared: `src/shared` → `ReplicatedStorage.shared`
- Server: `src/server` → `ServerScriptService.server`
- Client: `src/client` → `StarterPlayer.StarterPlayerScripts.client`
