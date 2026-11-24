# Source index

A curated map of where behaviour lives. Paths are relative to the repository root.

## Server

| Area | Path |
|---|---|
| Combat service and hooks | `src/server/services/CombatService/` |
| Skill / Spec / Hook / Projectile classes | `src/server/combat-classes/` |
| Skills | `src/server/skills/` (shared at root, character-specific in subfolders) |
| Specs | `src/server/specs/` |
| Components | `src/server/components/` |
| Player modules | `src/server/player-modules/` |
| Quests | `src/server/quests/` |
| Bot AI | `src/server/services/BotService/` |
| Terminal commands/hooks | `src/server/terminal-commands/`, `src/server/terminal-hooks/` |
| Public types | `src/server/types.luau` |
| Enums | `src/server/Enums.luau` |

## Client

| Area | Path |
|---|---|
| Services | `src/client/services/` |
| Components | `src/client/components/` |
| Controls | `src/client/controls/` |
| UI | `src/client/ui/` (`components/`, `views/`, `utils/Router`, `stories/`, `main.luau`) |
| Player modules | `src/client/player-modules/` |
| Public types | `src/client/types.luau` |

## Shared

| Area | Path |
|---|---|
| Configs | `src/shared/configs/` (`Specs.luau`, `Skins/`, `Quests/`, `Bots/`, `BotSpawners/`) |
| Schemas | `src/shared/schemas/` |
| Combat helpers | `src/shared/combat/` (`Block`, `ChargeState`, `Knockback`) |
| Effects | `src/shared/effects/` |
| Components | `src/shared/components/Stand/` |
| Vendored packages | `src/shared/packages/` (read-only) |

## Tooling

`tools/`, `default.project.json`, `.luaurc`, `stylua.toml`, `.gitignore`.

Related: [[Repository and Rojo layout]], [[Types index]], [[Developer map]].
