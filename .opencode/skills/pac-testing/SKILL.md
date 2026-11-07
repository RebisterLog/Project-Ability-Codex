---
name: pac-testing
description: PAC testing/gates: lune suites, quality gates, baseline, skill harness usage.
---

# PAC Testing

## Commands
```bash
lune run tools/run-tests.luau                # gates + all suites
lune run tools/run-tests.luau --json         # machine-readable report
lune run tests/skills/Contract.luau          # all skills contract/assets/runnable
lune run tests/skills/Uppercut.luau          # one suite
lune run src/shared/packages/SkillConstructor/tests/structural.luau
lune run tools/skills.luau list              # driveable skills
lune run tools/skills.luau inspect Punch     # frame-by-frame text
lune run tools/check.luau                   # all gates
lune run tools/check.luau --only=lint       # selene
lune run tools/check.luau --strict          # skipped gate = failure
lune run tools/check.luau --json
lune run tools/check.luau --update-baseline # accept current findings (after review)
lune run tools/format.luau                  # check tools/tests
lune run tools/format.luau --fix --src      # format src too
```

## Gates
- syntax: `luau-compile` (parse), ~100ms
- format: `stylua --check` (formatting drift)
- lint: `selene` (unused, shadowing, global_usage)
- analyze: `luau-lsp` (types)
Order by cost; each makes sense only if previous clean. Only new findings fail in src (baseline in `tests/baseline/`).

## Skill harness
```luau
local world = Harness.world({ spec = "Standless", skin = "None", targets = 2 })
local skill = world:skill("Standless/Uppercut")
skill:Activate()
world:Step(40)
for _, hit in world.trace:attacks() do print(hit.frame, hit.damage) end
```
Skills run headlessly: real skill source + skin + params + Enums; Roblox/Crane/services/Skill class recorded not run. Add suites under `tests/skills/` when editing skills; assert hit frames, who gets hit and damage, armor/params released. Contract keeps all 17 skills runnable.

## Tips
- Individual suites run as separate processes; one failure doesn't hide others.
- Vendored paths excluded from all gates.
- Missing tools skip gate with warning; `--strict` makes it fail.
- `lune setup` once for `@lune/*` alias resolution.
