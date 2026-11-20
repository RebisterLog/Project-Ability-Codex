# PAC - AI Agent Guidance (compact)

Start here: `docs/AI_CONTEXT.md` (Rojo paths, naming, pragmas, commands, gotchas). Full long-form docs remain in `docs/`.

## Load skill by task
- Combat skill module → skill `create-combat-skill` (also `pac-combat`)
- Spec/skin/spec config → skill `create-spec`
- UI element → skill `create-ui-element`
- Luau/idioms/conventions → skill `pac-luau`
- Crane (services/components/signals/packets) → skill `pac-crane`
- Attack/Sequencer/VFX/params → skill `pac-combat`
- Testing/gates/baseline → skill `pac-testing`
- Studio Bridge → skill `pac-bridge`
- Performance/Proxy → skill `pac-performance`

## Testing
See `docs/TESTING.md`. Headless:
```
lune run tools/run-tests.luau                 # gates + every suite
```

## Runtime Bridge (Studio only)
`src/shared/packages/Bridge/`, `src/server/services/BridgeService.luau`, `src/client/services/BridgeService.luau`.
Server: `ServerScriptService.Bridge`; Client: `ReplicatedStorage.Bridge`.
Envelope `{ Id, Op, Args }`; read matching `{ Id, Ok, Value|Error }`. `bridge.help` for catalog. See `docs/BRIDGE.md`, skill `pac-bridge`. Studio only; never reachable in published game.

## Editor / gates
Zed config `.zed/settings.json` committed. Format on save via `stylua --stdin-filepath {buffer_path} -`. Line endings `detect` (mixed CRLF/LF; do not force). Vendored read-only.
```
lune run tools/check.luau                 # syntax, format, lint, analyze
lune run tools/check.luau --only=lint
lune run tools/check.luau --update-baseline
```
Gates: syntax (luau-compile), format (stylua), lint (selene), analyze (luau-lsp). Style in StyLua, lint in Selene; do not overlap. `selene.toml` disables multiple_statements because StyLua collapses `if x then return end`. `Toolchain.VENDORED` and selene exclude list must stay in sync (11 paths).

## Project standards & structure
- `docs/CODING_STANDARDS.md` — full conventions, architecture, patterns.
- `docs/PROJECT_STRUCTURE.md` — combat components & server impl.
- `docs/GOTCHAS.md` — known traps (read before risky edits).

## Project structure (Rojo)
- Shared: `src/shared` → `ReplicatedStorage.shared`
- Server: `src/server` → `ServerScriptService.server`
- Client: `src/client` → `StarterPlayer.StarterPlayerScripts.client`