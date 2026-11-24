# Implemented systems

Snapshot of what exists in the codebase. Verify against source before relying on a detail.

| System | State | Entry point |
|---|---|---|
| Combat core | Implemented: hitboxes, hooks, sequences, attack states | `src/server/services/CombatService/` |
| Skill class and lifecycle | Implemented | `src/server/combat-classes/Skill.luau` |
| Specs | Implemented for Gerson, JonathanHamon, Standless, StarPlatinum, TheWorld, Undyne | `src/server/specs/` |
| Skills | Implemented, including shared and character-specific sets | `src/server/skills/` |
| SubSpec slot | Supported by spec slots and bind resolution | [[Spec and SubSpec]] |
| VFX replication | Implemented | `src/server/services/VFXService/`, `src/shared/effects/` |
| Proxies | Implemented with patch/subscribe replication | [[Data schemas and Proxy]] |
| Bot AI | Implemented with action slot, roles and posture | [[Bot combat AI]] |
| Quests | Minimal test quest only | `src/server/quests/Test/` |
| UI | Fusion-based components/views with stories and Router | `src/client/ui/` |
| Terminal commands | Implemented | `src/server/terminal-commands/` |
| Studio Bridge | Implemented, Studio-only | [[Bridge (Studio only)]] |
| Lore | Not written; templates and name seeds only | [[Lore home]] |
| Verification tooling | `context`, `format`, `impact` only; no test runner or gates | [[Formatting and inspection]] |

Related: [[Known gaps and roadmap]], [[Developer map]].
