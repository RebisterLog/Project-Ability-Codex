# Gotchas

Read before risky edits. These are non-obvious traps found in the codebase.

1. **`Component:GetId()` always returns nil.** `Component.luau` reads attribute `CraneComponentId`, but Crane writes `CraneComponentIdSERVER` / `CraneComponentIdCLIENT`. Read the attribute directly until reconciled.
2. **Duplicate `Character` components after respawns.** Several components can stack on the same model. Check counts; never assume one.
3. **Mixed CRLF/LF.** Do not force a global LF conversion. It produces ` M` in git with an empty diff. Editor line endings stay at `detect`.
4. **Vendored packages are read-only.** The formatter skips them through `Toolchain.vendoredSet`; the editor uses read-only globs as a second layer. `Signal.luau` is excluded by default.
5. **Formatting is line-ending aware.** `tools/format.luau` groups files by CRLF/LF and formats each group separately, so a fix never rewrites endings wholesale.
6. **No automated test runner or gates remain.** Verification is manual playtest plus `context`, `format` and `impact`. See [[Formatting and inspection]].
7. **Bridge is Studio-only.** Both Bridge services check `RunService:IsStudio()`; never expose it in a published game. See [[Bridge (Studio only)]].
8. **Proxy `AnyChange` fires on prefix matches.** Replacing a parent does not notify subscribers deeper than that parent. A no-op patch fires nothing.
9. **Zed format-on-save needs `--stdin-filepath`.** Without it StyLua cannot find its config.
10. **Pragmas go at the very top.** `--!native` / `--!optimize 2` before any `require`; `--!strict` for typed modules.
11. **Knockback `Hold` is a lifetime, not damping.** See [[Knockback and movement]].
12. **Binds have no Hold flag.** Repeated requests are validated on the server; see [[Input and BindService]].

Related: [[Formatting and inspection]], [[Data schemas and Proxy]], [[Runtime boundaries]].
