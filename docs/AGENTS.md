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

## Project Standards
- See `CODING_STANDARDS.md` for full coding conventions, architecture principles, and patterns.
- See `PROJECT_STRUCTURE.md` for details on combat components and server implementation.
