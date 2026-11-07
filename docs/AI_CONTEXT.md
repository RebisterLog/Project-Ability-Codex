# PAC (Project-Ability-Codex) — AI Context Card

Read this FIRST before touching code. Compact reference; full details in skills.

## Rojo mapping (paths)
- `src/shared` → `ReplicatedStorage.shared`
- `src/server` → `ServerScriptService.server`
- `src/client` → `StarterPlayer.StarterPlayerScripts.client`
- Vendored read-only packages under `src/shared/packages/*` (Roact, Fusion, Crane, Janitor, Proxy, Sequencer, etc.) — see `tools/Toolchain.VENDORED` + `selene.toml` exclude list (must stay in sync).

## Pragmas
- Performance-critical server combat code: `--!native` / `--!optimize 2`
- Type-checked modules: `--!strict`

## Module pattern
- Every module returns one value (table/class/function).
- Two call conventions coexist: colon `function Skill:Activate()` (preferred for new) and dot `function Skill.Activate(self)`; match the file.
- Public types live in `src/server/types.luau` (`export type`).
- All function params must be annotated; return types on public fns.

## Naming
| Scope | Convention |
|---|---|
| Module/Class | PascalCase |
| Variable/function | camelCase |
| Constants | PascalCase/UPPER_CASE |
| Files | PascalCase classes, camelCase utils |
| Types | PascalCase (`types.SkillData`) |
| Service methods | PascalCase (`CombatService:Hitbox`) |

## Crane (global `Crane`)
- Service: `local S = Crane:CreateService({ Name="..." })`; lifecycle `onInit`/`onStart`.
- Component: `Crane:CreateComponent({ Name="..." })`; `self.instance`.
- Access: `Crane:GetService`, `Crane:GetComponent`.
- Cleanup: `Crane.Janitor` / `Crane.Buttler`; `self.Janitor:Add(obj, "Destroy")`.
- Signals: `Signal()`; packets: `Crane:GetPacket("...")`.

## Standard commands
```bash
lune run tools/run-tests.luau                # gates + all suites
lune run tools/check.luau                    # syntax/format/lint/analyze
lune run tools/check.luau --only=lint
lune run tools/check.luau --update-baseline  # accept current findings
lune run tools/gen-types-doc.luau         # docs/API_TYPES.md
lune run tools/sync-docs.luau        # download/update docs/ref
```
- Tools resolved via `PAC_TOOLS_DIR`, `<root>/.tools`, PATH.

## Agent helpers
```bash
lune run tools/context.luau            # repo/session snapshot
lune run tools/context.luau --json
lune run tools/impact.luau src/...      # blast radius / dependents
lune run tools/impact.luau Proxy        # by identifier
```

## Line endings / formatting
- `core.autocrlf=on`, no `.gitattributes`: 208 files CRLF, 820 LF. DO NOT force LF globally.
- Zed formats on save via `stylua --stdin-filepath {buffer_path} -` (makes stylua find `stylua.toml`).
- Vendored are read-only in editor.

## Where to look next
- Luau/idioms → skill `pac-luau`
- Crane patterns → skill `pac-crane`
- Combat (AttackHook/AttackInfo/Sequencer) → skill `pac-combat`
- Testing/gates → skill `pac-testing`
- Bridge (Studio-only) → skill `pac-bridge`
- Performance principles → skill `pac-performance`
- Known traps → `docs/GOTCHAS.md`
