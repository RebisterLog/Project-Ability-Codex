# PAC — Agent guidance

Documentation lives in `obsidian/` (English, canonical) with a complete Russian mirror in `obsidian/i18n/ru/`. Read the relevant note before editing code; update the note and its ` (RU)` twin when behaviour changes.

## Project basics

- Rojo mapping: `src/shared` → `ReplicatedStorage.shared`; `src/server` → `ServerScriptService.server`; `src/client` → `StarterPlayer.StarterPlayerScripts.client`.
- Pragmas: `--!strict` for type-checked modules; `--!native` and `--!optimize 2` at the top of performance-critical server combat code, above any `require`.
- Naming: PascalCase modules/classes/types, camelCase variables and functions, PascalCase service methods. Two call conventions coexist; match the file (`function Skill:Activate()` is preferred for new code).
- Crane: services via `Crane:CreateService({ Name = "..." })` with `onInit` / `onStart`; components via `Crane:CreateComponent`; access with `Crane:GetService` / `Crane:GetComponent`; cleanup with `Crane.Janitor` / `Crane.Buttler`; signals with `Signal()`; packets with `Crane:GetPacket`.
- Vendored libraries under `src/shared/packages/` are read-only and skipped by the formatter.
- Line endings are mixed CRLF/LF. Do not force a global conversion.
- Verification: there is no automated verification suite. Format with `lune run tools/format.luau --fix --src`; inspect with `lune run tools/context.luau` and `lune run tools/impact.luau <target>`; playtest manually in Studio.

## Route by task

| Task | Read first |
|---|---|
| Combat skill | `obsidian/04-How-to/Create a combat skill.md`, then `obsidian/03-Combat/Skill contract and lifecycle.md` and `obsidian/03-Combat/Sequencer.md` |
| Spec or subspec | `obsidian/04-How-to/Create a spec.md`, `obsidian/04-How-to/Create a subspec.md`, `obsidian/02-Architecture/Spec and SubSpec.md` |
| Attack / damage / block | `obsidian/03-Combat/AttackInfo and AttackData.md`, `obsidian/03-Combat/Attack hooks.md`, `obsidian/03-Combat/Character parameters.md` |
| Hitbox / knockback / VFX | `obsidian/03-Combat/Hitbox and targeting.md`, `obsidian/03-Combat/Knockback and movement.md`, `obsidian/03-Combat/VFX replication.md` |
| Bot behaviour | `obsidian/03-Combat/Bot combat AI.md` |
| Proxy / replication / input | `obsidian/02-Architecture/Data schemas and Proxy.md`, `obsidian/02-Architecture/Input and BindService.md` |
| UI element | `obsidian/04-How-to/Create a UI element.md` |
| Quest | `obsidian/04-How-to/Add a quest.md` |
| Service / component / hook | `obsidian/04-How-to/Create a service or component.md`, `obsidian/04-How-to/Create a hook.md` |
| Formatting and inspection | `obsidian/04-How-to/Formatting and inspection.md`, `obsidian/05-Reference/Gotchas.md` |
| Studio-only runtime control | `obsidian/05-Reference/Bridge (Studio only).md` |
| Newcomer orientation | `obsidian/Home.md`, `obsidian/01-Maps/Developer map.md` |

## Before risky edits

Read `obsidian/05-Reference/Gotchas.md`. Do not assume a test runner exists, do not expose Studio-only tooling in a published game, and do not assume one component per instance after respawns.
