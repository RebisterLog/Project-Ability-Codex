# Repository and Rojo layout

## Root

| Path | Role |
|---|---|
| `src/` | All first-party Luau code. |
| `tools/` | Lune scripts: `context`, `format`, `impact`, `Toolchain`, plus starter templates. |
| `obsidian/` | This documentation vault. |
| `AGENTS.md` | Short agent rules and a route into the vault. |
| `default.project.json` | Rojo project definition. |
| `.luaurc`, `stylua.toml`, `.gitignore` | Alias/analyzer config, formatter config, ignore rules. |
| `README.md`, `LICENSE` | Entry point and licence. |

The headless verification scripts were removed from the tooling; see [[Formatting and inspection]].

## Rojo mapping

| Source | Roblox container |
|---|---|
| `src/shared` | `ReplicatedStorage.shared` |
| `src/server` | `ServerScriptService.server` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.client` |

The same module path is required from all three sides through those containers. Do not hard-code an absolute `game` path when a Rojo-relative path works.

## `src/` in brief

- `src/server/`: `services/` (singletons), `components/` (instance-bound logic), `combat-classes/` (`Skill`, `Spec`, `Hook`, `Projectile`, charges), `skills/`, `specs/`, `player-modules/`, `quests/`, `terminal-commands/`, `Configuration/`, `types.luau`, `Enums.luau`.
- `src/client/`: `services/`, `components/`, `controls/`, `ui/` (Fusion component/view split, `Router`, stories), `player-modules/`, `skills/`, `types.luau`.
- `src/shared/`: `packages/` (vendored, read-only), `configs/`, `schemas/`, `effects/`, `combat/`, `components/`.

## Rules

1. Vendored packages under `src/shared/packages/` are read-only and skipped by the formatter.
2. `src/shared` must not assume a single machine: code there may run on both server and client.
3. Keep public types in `src/server/types.luau`, `src/client/types.luau` and `src/shared/schemas/`. See [[Types index]].
4. Build with `rojo build -o PAC.rbxlx`, serve with `rojo serve`.

Related: [[Runtime boundaries]], [[Services and dependencies]], [[Source index]].
