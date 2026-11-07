---
name: pac-luau
description: Luau/Roblox idioms and PAC conventions (pragmas, types, naming, module pattern) for Project-Ability-Codex.
---

# PAC Luau Conventions

## Pragmas
- Server combat/perf files: top of file `--!native` then `--!optimize 2`.
- Type-checked modules: `--!strict`.
- Pragmas go above requires.

## Type exports
- Public types in `src/server/types.luau` via `export type`.
- All function params annotated; return types on public fns.
- Cast `:: TypeName`; use `typeof()` for complex inferred types.

## Naming
| Scope | Convention |
|---|---|
| Module/Class | PascalCase |
| Variable/function | camelCase |
| Constants | PascalCase or UPPER_CASE |
| Files | PascalCase classes, camelCase utils |
| Types | PascalCase (`types.SkillData`) |
| Service methods | PascalCase |
| Private fields | PascalCase (table keys) `self.Sequence` |

## Module pattern
- Module returns a single value.
```luau
local Skill: types.SkillData = { DisplayName = "X" }
function Skill.onInit(self) end
function Skill:Activate() end
return Skill
```
- Colon syntax preferred for new code; match existing file when editing.
- Skills/services return tables; components return component tables.

## Common idioms
- Optional chaining not available; use `if x ~= nil then`.
- `task.wait()`/`task.spawn`; avoid deprecated `wait`/`spawn`.
- Use `table.find`, `table.insert`, `table.clear`.
- Arrays come back from Bridge with string keys + Count.
- `::` casts; avoid `any` unless necessary (analyze gate).

## Forbidden/gotchas
- Vendored packages under `src/shared/packages/*` (Roact, Fusion, Crane, Lapis, etc.) are read-only team rules. Do not edit.
- `tools/` and `tests/` have zero-findings rule (selene). `src` has baseline.
- Style (StyLua) vs lint (Selene) must not overlap.

## File placement
- `src/server/skills/` for skills; `src/server/skills/CharName/` for character-unique.
- Services: `src/server/services/*.luau`.
- Types: `src/server/types.luau`.
- Shared schemas: `src/shared/schemas/*.luau`.

## More
Combat: skill `pac-combat`; Crane: `pac-crane`; testing: `pac-testing`.