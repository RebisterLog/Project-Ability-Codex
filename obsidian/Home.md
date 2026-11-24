# Home

This vault is the canonical documentation for **PAC (Project-Ability-Codex)**. It is written for a developer who has just joined the project and needs a reading route, not a pile of disconnected notes.

- **Language:** English is the source of truth. A complete Russian mirror lives in `i18n/ru/` (every note has a ` (RU)` twin and a link back to the original).
- **How to read:** follow one of the three maps below. Each map is an ordered route; the glossary is available at any point.
- **How to cite code:** paths are relative to the repository root, e.g. `src/server/services/CombatService/init.luau`.

## Reading routes

| Role | Start here |
|---|---|
| Developer / gameplay programmer | [[Developer map]] |
| Designer / gameplay tuner | [[Designer map]] |
| Writer / lore contributor | [[Lore map]] |
| Anyone, quick orientation | [[Glossary]] |

## What is documented

1. [[Repository and Rojo layout]] — where files live and where they run.
2. [[Runtime boundaries]] — server authority, client presentation, shared code.
3. [[Services and dependencies]] — the service graph.
4. [[Player and character lifecycle]] — from join to an active spec.
5. [[Spec and SubSpec]] — character loadouts and slots.
6. [[Combat pipeline]] — the full attack path.
7. [[Skill contract and lifecycle]] — how a skill is built and registered.
8. [[AttackInfo and AttackData]] — damage, block, stun, knockback and result states.
9. [[Bot combat AI]] — NPC decision loop.
10. [[Formatting and inspection]] — how to verify a change.
11. [[Lore home]] — intentionally empty lore templates and name seeds.

## Conventions used in this vault

- Wikilinks (double square brackets) connect notes; a note's title is its filename.
- Lua snippets are illustrative; always confirm against the current source file.
- Notes describe **mechanisms and contracts**. Exact constants live in code.
- When code changes, update the note and its Russian twin together.

For agent-specific rules, see `AGENTS.md` in the repository root.
