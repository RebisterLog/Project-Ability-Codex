# Formatting and inspection

The repository no longer ships an automated verification suite. Verification is a combination of manual playtest in Studio and three small Lune tools.

## Current tools

| Tool | Command | Purpose |
|---|---|---|
| Context | `lune run tools/context.luau` (`--json`) | Snapshot: branch/head, modified files, source/skill/spec counts, availability of `lune`, `stylua`, `rojo`. |
| Format | `lune run tools/format.luau` (`--fix`, `--src`, `--exclude`) | Check or apply StyLua formatting. |
| Impact | `lune run tools/impact.luau <path-or-identifier>` (`--json`) | Blast radius: list files that reference a path or identifier. |

`tools/Toolchain.luau` is a shared library for these scripts, not a command. It locates binaries through `PAC_TOOLS_DIR`, the directory next to `lune`, `<root>/.tools` and `PATH`, and defines the vendored path list that is never formatted or scanned.

## Formatting

```bash
lune run tools/format.luau                      # check tools/
lune run tools/format.luau --fix                # format tools/
lune run tools/format.luau --fix --src          # format tools/ and src/
lune run tools/format.luau --exclude a.luau,b/  # additional exclusions
```

`stylua.toml` requests Unix line endings, but a Windows checkout arrives with CRLF. The script groups files by their current endings and runs StyLua once per group, so `--fix` never rewrites line endings wholesale. Vendored packages under `src/shared/packages/` are skipped; `Signal.luau` is excluded by default. If StyLua is missing, the script prints a hint instead of failing.

## Inspection

```bash
lune run tools/context.luau
lune run tools/impact.luau CombatService
lune run tools/impact.luau src/shared/combat/Knockback.luau --json
```

Use `impact` before changing a widely used module; use `context` when you need a quick orientation in an unfamiliar working copy.

## Editor tasks

`.zed/tasks.json` provides three tasks: `Format` (the `--fix --src` command above), `Rojo: Build` and `Rojo: Server`.

## Verification workflow

1. Run `rojo build -o PAC.rbxlx` or rely on a live Rojo server.
2. Run the formatting check/fix.
3. Use `impact` to see what a change touches.
4. Playtest the relevant behaviour manually in Studio. There is no automated suite to fall back on.

Related: [[Gotchas]], [[Templates and generators]], [[Repository and Rojo layout]].
