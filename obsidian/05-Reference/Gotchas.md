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
13. **ByteNet's 512 B/s is shared by every client→server packet.** Both reliable and unreliable remotes pass the same limiter (`ByteNet/process/server.luau`), so a high-frequency pose stream must be throttled and diffed; see [[Lag compensation]].
14. **Client services run inside the `Main` Actor.** `RenderStepped` is not dispatched there; use `Heartbeat` for client-service frame work (as `BindService` does).
15. **Only `const` is valid; `let` and `var` do not parse.** Luau rejects them with `Incomplete statement: expected assignment or a function call`, which breaks module loading before the game starts. StyLua (`tools/format.luau`) does **not** catch this, so run `luau-compile --only-parse` over `src/**/*.luau` as an extra check when adding lots of code. `keyof typeof Config.Models` is also invalid — use a bare identifier.
16. **Removing a parameter never stops its VFX.** A watcher only sees the folded value; after `AddParameter:Destroy()` it is the default, so the expired entry is gone. Stop effects explicitly in the owning timer/cleanup (see `Hooks/Sever.luau`). `Bleed.Slow = 0` disables the bleed slow; `nil` keeps the legacy 8 studs/s cap.
17. **`Cooldown = 0` used to erase manual cooldowns.** `Skill.Activate` now applies `Data.Cooldown` only when it is `> 0`; skills that call `self:SetCooldown(...)` themselves should omit the field (or leave it 0) so the manual timer survives activation and interruption.
18. **The server entrypoint must stay `runtime.server.luau`.** Rojo turns `.server.luau` into a `Script` and plain `.luau` into a `ModuleScript`; renaming it to `runtime.legacy.luau` silently stops Crane on the server, so clients hang on ByteNet's `WaitForChild("BytenetStorage")`.

Related: [[Formatting and inspection]], [[Data schemas and Proxy]], [[Runtime boundaries]].
