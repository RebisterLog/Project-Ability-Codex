# PAC — Known Gotchas / Traps

Short list of non-obvious pitfalls discovered in the codebase. Read before risky edits.

## 1. `Component:GetId()` always returns nil
`Component.luau` reads attribute `"CraneComponentId"`, but `Crane/init.luau` writes `"CraneComponentIdSERVER"` (server) / `"CraneComponentIdCLIENT"` (client). Until reconciled, read the attribute directly.

## 2. Duplicate `Character` components after respawns
After several respawns, `crane.component.list` reports many `Character` components stacked on the same Model. Something re-adds without removing the old one. Check counts; do not assume one component per model.

## 3. CRLF/LF split — do not force global LF
Index stores 820 files as LF; `core.autocrlf=on` and no `.gitattributes` makes git hand 208 back as CRLF. Forcing LF makes `git status` show ` M` while `git diff` stays empty. Editor line endings stay at `detect`. Normalizing requires its own commit (`.gitattributes` + `core.autocrlf=false`).

## 4. Vendored packages are read-only in Zed
StyLua cannot skip paths in stdin mode, so `read_only_files` is the only lever. Editing Roact/Fusion/Crane means removing the glob.

## 5. Formatting: StyLua has no "Auto" line endings
`lunaut.format.enabled` handles format-on-save through StyLua; use `lune run tools/format.luau --fix --src` for a whole-project pass. StyLua only offers `Unix` or `Windows` line endings, so a plain `stylua src` would rewrite every CRLF file. `tools/format.luau` splits files by their current endings and preserves them.

## 6. Bridge exists only in Studio playtest
Both server/client `BridgeService` check `RunService:IsStudio()` before creating instances; `Ops.Run` re-checks. Do not expose Bridge in published game. Fire `{ Id, Op, Args }` on `Request`, read matching response. Limits: depth 6, 500 nodes, 200 keys/table, 4096 chars/string, 150 props/Instance. Arrays come back with string keys + `Count`.

## 7. Signals/packets contracts
- `AnyChange` fires when subscribed path is a **prefix** of changed path. Replacing a parent does NOT notify deeper subscribers.
- A patch that changes nothing produces no callback and is not forwarded to `OnPatch`.

## 8. Performance pragmas placement
`--!native` / `--!optimize 2` at top of file for server combat. `--!strict` for type-checked modules. Keep them above any requires.
