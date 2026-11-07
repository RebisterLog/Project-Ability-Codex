---
name: pac-testing
description: PAC testing/gates: lune suites, quality gates, baseline.
---

# PAC Testing

## Commands
```bash
lune run tools/run-tests.luau                # gates + all suites
lune run tools/run-tests.luau --json         # machine-readable report
lune run src/shared/packages/SkillConstructor/tests/structural.luau
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

## Tips
- Individual suites run as separate processes; one failure doesn't hide others.
- Vendored paths excluded from all gates.
- Missing tools skip gate with warning; `--strict` makes it fail.
- `lune setup` once for `@lune/*` alias resolution.
