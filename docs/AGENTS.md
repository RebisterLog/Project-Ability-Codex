# PAC - OpenCode Agent Guidance

## Project Structure (via Rojo)
- Shared code: `src/shared` → `ReplicatedStorage.shared`
- Server code: `src/server` → `ServerScriptService.server`
- Client code: `src/client` → `StarterPlayer.StarterPlayerScripts.client`

## AI Skill Files

### Creating Combat Skills
Load the **create-combat-skill** skill when creating or editing a combat skill module (`src/server/skills/*.luau`):
```
skill load create-combat-skill
```

### Creating Specs
Load the **create-spec** skill when creating or editing a spec module, skin config, or spec configuration (`src/server/specs/*.luau`, `src/shared/configs/Skins/*/*.luau`, `src/shared/configs/Specs.luau`):
```
skill load create-spec
```

## Testing

Combat skills run headlessly, without Studio and without a playtest. See `TESTING.md`.

```bash
lune run tools/run-tests.luau                        # gates + every suite
lune run tests/skills/Contract.luau                  # every skill: contract, assets, runnable
lune run tools/skills.luau inspect Standless/Uppercut  # one skill, frame by frame
```

Write a suite under `tests/skills/` when editing a skill: assert which frames check the
hitbox, who gets hit and for how much damage, and that armor and parameters are released.
`lune run tools/skills.luau list` shows which skills the harness can drive — all of them.

## Runtime Bridge

During a Studio playtest, Crane services and components can be called directly over
MCP instead of by editing a script to ask for something. See `BRIDGE.md`.

| Side | Container | Address it from |
|---|---|---|
| Server | `ServerScriptService.Bridge` | `execute_luau` with `datamodel_type: "Server"` |
| Client | `ReplicatedStorage.Bridge` | `execute_luau` with `datamodel_type: "Client"` |

Send `{ Id = <guid>, Op = <op>, Args = { ... } }` on `Request`, read the matching
`{ Id, Ok, Value | Error }` off `Response`. Call `bridge.help` for the full
operation catalog.

The Bridge only exists inside a Studio playtest. It is not present in a published
game and must not be made reachable there.

## Editor

Zed is configured in `.zed/settings.json`, and it is committed on purpose: the rules in
`tools/` are team rules, and the editor is where they are felt first.

- **Format on save.** Luau buffers go through `stylua --stdin-filepath {buffer_path} -`
  on every save. `--stdin-filepath` is what makes StyLua find `stylua.toml`; without it
  the config is looked up in whatever directory Zed spawns the process in.
- **Line endings stay at `detect`,** which is Zed's default, and that is deliberate. The index
  stores all 820 files as LF, but `core.autocrlf` is on and there is no `.gitattributes`, so
  git hands 208 of them back with CRLF. Forcing LF in the editor was measured on this repo
  and it makes things worse: rewriting one of those files to LF leaves `git status` reporting
  ` M` while `git diff` stays empty, so the file never settles. `detect` keeps each file's
  own ending, which is what git already expects per file. Normalizing the repository with a
  `.gitattributes` and `core.autocrlf=false` would remove the split entirely, and is worth
  doing as its own commit.
- **Vendored packages are read-only.** StyLua cannot be told to skip a path when it
  formats from stdin — `.styluaignore`, `--respect-ignores` and `--glob '!…'` are all
  ignored in that mode — so `read_only_files` is the only lever. It is a hard block:
  Zed has no action to toggle it, so editing Roact or Fusion from the editor means
  removing the glob.

### Gates

```bash
lune run tools/check.luau                   # syntax, format, lint, analyze
lune run tools/check.luau --only=lint       # just the selene gate
lune run tools/check.luau --update-baseline # accept the current findings
```

| Gate      | Tool           | Answers                                    |
| --------- | -------------- | ------------------------------------------ |
| `syntax`  | `luau-compile` | does it parse at all                       |
| `format`  | `stylua`       | is it formatted                            |
| `lint`    | `selene`       | unused variables, shadowing, `global_usage`|
| `analyze` | `luau-lsp`     | types                                      |

Style belongs to StyLua and lint questions belong to Selene, so the two must not overlap.
`selene.toml` turns `multiple_statements` off because `stylua.toml` collapses
`if x then return end` on purpose; `Toolchain.VENDORED` and the `exclude` list in
`selene.toml` are the same eleven paths and have to stay in sync.

Selene is not a language server and Zed has no adapter for it, so it produces no inline
diagnostics — it is a gate you run, not something the editor runs for you.

## Project Standards
- See `CODING_STANDARDS.md` for full coding conventions, architecture principles, and patterns.
- See `PROJECT_STRUCTURE.md` for details on combat components and server implementation.
