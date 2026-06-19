# PAC - OpenCode Agent Guidance

## Build and Run
- Precompile structure `rojo sourcemap > sourcemap.json`
- Start Rojo server: `rojo serve`

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

## Project Standards
- See `CODING_STANDARDS.md` for full coding conventions, architecture principles, and patterns.
- See `PROJECT_STRUCTURE.md` for details on combat components and server implementation.
