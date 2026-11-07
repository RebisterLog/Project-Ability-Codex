# PAC — Known Gotchas / Traps

Short list of non-obvious pitfalls discovered in the codebase. Read before risky edits.

## 1. `Component:GetId()` always returns nil
`Component.luau` reads attribute `"CraneComponentId"`, but `Crane/init.luau` writes `"CraneComponentIdSERVER"` (server) / `"CraneComponentIdCLIENT"` (client). Until reconciled, read the attribute directly.

## 2. Duplicate `Character` components after respawns
After several respawns, `crane.component.list` reports many `Character` components stacked on the same Model. Something re-adds without removing the old one. Check counts; do not assume one component per model.

## 3. CRLF/LF split — do not force global LF
Index stores 820 files as LF; `core.autocrlf=on` and no `.gitattributes` makes git hand 208 back as CRLF. Forcing LF makes `git status` show ` M` while `git diff` stays empty. Editor line endings stay at `detect`. Normalizing requires its own commit (`.gitattributes` + `core.autocrlf=false`).

## 4. Vendored packages are read-only in Zed
StyLua cannot skip paths in stdin mode, so `read_only_files` is the only lever. Editing Roact/Fusion/Crane means removing the glob. `Toolchain.VENDORED` and `selene.toml` exclude list (11 paths) must stay in sync.

## 5. Formatting gate nuances
- `stylua.toml` Unix line endings; Windows checkout has mixed. Two-pass format check: a file differing only in endings is NOT unformatted.
- Auto-format preserves each file's current endings.
- Gate order: syntax → format → analyze; each only meaningful if previous clean.

## 6. Baseline findings don't fail gates
Findings already present in `src` are listed in `tests/baseline/` and do not fail — only new ones do. `tools/` and `tests/` held to zero. Regenerate with `--update-baseline` only after reviewing diff. Never silently accept.

## 7. Bridge exists only in Studio playtest
Both server/client `BridgeService` check `RunService:IsStudio()` before creating instances; `Ops.Run` re-checks. Do not expose Bridge in published game. Fire `{ Id, Op, Args }` on `Request`, read matching response. Limits: depth 6, 500 nodes, 200 keys/table, 4096 chars/string, 150 props/Instance. Arrays come back with string keys + `Count`.

## 8. Signals/packets contracts
- `AnyChange` fires when subscribed path is a **prefix** of changed path. Replacing a parent does NOT notify deeper subscribers.
- A patch that changes nothing produces no callback and is not forwarded to `OnPatch`.

## 9. Zed format on save needs `--stdin-filepath`
Without it, StyLua looks up `stylua.toml` in whatever directory Zed spawns the process. Config is lost.

## 10. Headless skill tests are the gate for combat changes
Combat skills run under lune (no Studio/playtest). If you edit a skill, add/adjust suite in `tests/skills/`. `Contract.luau` loads every skill and fails if one cannot run. All 17 real skills must remain runnable.

## 11. Performance pragmas placement
`--!native` / `--!optimize 2` at top of file for server combat. `--!strict` for type-checked modules. Keep them above any requires.