# PAC Project Structure

## Overview
This document outlines the structure of the PAC (Project Adventure Combat) Roblox game, with emphasis on combat components and server-side implementation.

## Directory Structure

```
PAC/
├── src/
│   ├── client/           # Client-side code (runs on player devices)
│   │   ├── components/   # Visual and interactive components
│   │   │   ├── Character.luau    # Client character representation
│   │   │   └── Player.luau       # Player-specific client logic
│   │   ├── controls/     # Input handling systems
│   │   │   ├── JoystickBinds.luau
│   │   │   ├── Keyboard.luau
│   │   │   └── Mobile.luau
│   │   ├── services/     # Client-side services
│   │   │   ├── BindService.luau      # Input binding
│   │   │   ├── ChronoService.luau    # Time management
│   │   │   ├── PlayerService.luau    # Player data management
│   │   │   ├── TargetLockService.luau# Target locking system (COMBAT)
│   │   │   ├── UIService.luau        # User interface
│   │   │   └── VFXService.luau       # Visual effects (COMBAT)
│   │   └── ui/           # User interface components
│   │       ├── components/
│   │       ├── utils/
│   │       ├── view/
│   │       └── main.luau
│   │
│   ├── server/           # Server-side code (runs on game server)
│   │   ├── combat-classes/ # CORE COMBAT SYSTEM
│   │   │   ├── Hook              # Combat hook implementation
│   │   │   ├── Skill.luau        # Base skill class
│   │   │   └── Spec.luau         # Skill specifications
│   │   │
│   │   ├── components/     # Server-side components
│   │   │   ├── Character       # Server character logic (COMBAT)
│   │   │   ├── Player.luau     # Server player logic
│   │   │   └── Sample.luau
│   │   │
│   │   ├── player-modules/ # Player-specific server modules
│   │   │   ├── CharacterAdder.luau   # Adds characters to players
│   │   │   ├── Sample.luau
│   │   │   └── SpecModule.luau       # Handles skill specs (COMBAT)
│   │   │
│   │   ├── services/       # Server-side services
│   │   │   ├── BotService          # Bot/NPC management
│   │   │   ├── CombatService       # MAIN COMBAT LOGIC SERVICE
│   │   │   ├── ChronoService.luau  # Server time management
│   │   │   ├── CollisionService.luau# Collision detection (COMBAT)
│   │   │   ├── ConfigsService.luau # Configuration management
│   │   │   ├── GameDataService.luau# Game data persistence
│   │   │   ├── PathUtil.luau       # Pathfinding utilities
│   │   │   ├── PlayersService.luau # Player management
│   │   │   ├── Sample.luau
│   │   │   ├── SkillService.luau   # Skill execution service (COMBAT)
│   │   │   ├── SpecService.luau    # Skill specifications service (COMBAT)
│   │   │   ├── TestService.luau
│   │   │   └── VFXService.luau     # Visual effects service
│   │   │
│   │   ├── skills/         # Skill implementations
│   │   │   ├── Gerson/     # Gerson character skills
│   │   │   ├── Standless/  # Standless character skills
│   │   │   ├── Undyne/     # Undyne character skills
│   │   │   ├── Barrage.luau    # Barrage skill
│   │   │   ├── Block.luau      # Block skill
│   │   │   ├── Dash.luau       # Dash skill
│   │   │   ├── Grab.luau       # Grab skill
│   │   │   ├── Punch.luau      # Punch skill
│   │   │   ├── Run.luau        # Run skill
│   │   │   └── TEMPLATE.luau   # Skill template
│   │   │
│   │   ├── specs/          # Skill specifications data
│   │   │   ├── Gerson.luau   # Gerson skill specs
│   │   │   ├── Standless.luau# Standless skill specs
│   │   │   └── Undyne.luau   # Undyne skill specs
│   │   │
│   │   ├── Enums.luau      # Game enumerations
│   │   ├── runtime.legacy.luau # Legacy runtime code
│   │   └── types.luau      # Type definitions
│   │
│   └── shared/             # Shared code between client and server
│       ├── configs/        # Configuration files
│       │   ├── Bots/       # Bot configurations
│       │   ├── Skins/      # Character skins
│       │   ├── Chrono.luau # Chrono configuration
│       │   └── Specs.luau  # Specifications
│       │
│       ├── effects/        # Visual and gameplay effects
│       │   ├── Combat/     # COMBAT EFFECTS
│       │   │   ├── ...     # Various combat visual effects
│       │   │
│       │   ├── DamageIndicator/  # Damage display effects
│       │   ├── Specs/      # Specification-related effects
│       │   ├── Animation.luau    # Animation utilities
│       │   ├── Barrage.luau      # Barrage effect
│       │   ├── Crash.luau        # Crash effect
│       │   ├── Dash.luau         # Dash effect
│       │   ├── EmitParticle.luau # Particle emission
│       │   ├── Highlight.luau    # Highlight effect
│       │   ├── Hitbox.luau       # Hitbox visualization (COMBAT)
│       │   ├── Impact Frame.luau # Impact frame effect
│       │   ├── Ragdoll.luau      # Ragdoll physics
│       │   └── Sound.luau        # Sound effects
│       │
│       ├── packages/       # External libraries
│       │   ├── chrono/     # Time management library
│       │   ├── Crane/      # Unknown library
│       │   ├── Fusion/     # Reactive programming library
│       │   ├── Janitor/    # Cleanup utility
│       │   ├── Lapis/      # Unknown library
│       │   ├── Sequencer/  # Sequencing library
│       │   ├── Bezier.luau # Bezier curve utilities
│       │   ├── CacheTab.luau # Caching utilities
│       │   ├── DraftController.luau # Draft control
│       │   ├── Promise.luau # Promise implementation
│       │   ├── Proxy.luau  # Proxy pattern
│       │   └── Signal.luau # Signal/event system
│       │
│       ├── schemas/        # Data schemas
│       │   ├── GameData.luau     # Game data schema
│       │   ├── PlayerData.luau   # Player data schema
│       │   ├── PlayerDynamicData.luau # Dynamic player data
│       │   └── PlayerSaveData.luau # Player save data
│       │
│       ├── bot-characters.luau # Bot character definitions
│       └── ...             # Other shared files
```

## Combat Component Focus

### Core Combat Systems (Server-Side)
1. **CombatService** (`src/server/services/CombatService.luau`)
   - Main combat logic handler
   - Manages combat state, hit detection, damage calculation

2. **SkillService** (`src/server/services/SkillService.luau`)
   - Executes player skills
   - Manages skill cooldowns and activation

3. **SpecService** (`src/server/services/SpecService.luau`)
   - Handles skill specifications and data

4. **CollisionService** (`src/server/services/CollisionService.luau`)
   - Detects combat collisions

5. **Combat Classes** (`src/server/combat-classes/`)
   - Base `Skill.luau` class for all skills
   - `Spec.luau` for skill specifications
   - `Hook` implementation for combat hooks

6. **Skills** (`src/server/skills/`)
   - Individual skill implementations (Punch, Block, Dash, etc.)
   - Character-specific skill sets (Gerson, Standless, Undyne)

### Client-Side Combat Systems
1. **TargetLockService** (`src/client/services/TargetLockService.luau`)
   - Handles target acquisition and locking

2. **VFXService** (`src/client/services/VFXService.luau`)
   - Manages combat visual effects on client

### Shared Combat Elements
1. **Combat Effects** (`src/shared/effects/Combat/`)
   - Visual effects for combat actions
   - Hitbox visualization (`Hitbox.luau`)
   - Damage indicators

## Server Implementation Connections

### Key Server Communication Patterns
1. **Remote Events/Functions** (implied by Rojo structure)
   - Combat actions initiated from client → processed on server
   - Server sends combat results → client updates visuals

2. **Service Dependencies**
   - `CombatService` depends on:
     - `CollisionService` for hit detection
     - `SkillService` for skill execution
     - `SpecService` for skill data
     - `PlayersService` for player state

3. **Skill Execution Flow**
   - Client inputs skill request → Server `SkillService`
   - `SkillService` validates and executes skill via appropriate skill module
   - Skill module applies effects through `CombatService`/`VFXService`
   - Results replicated to clients

4. **Character-Server Interaction**
   - `src/server/components/Character` manages server character state
   - `CharacterAdder.luau` in player-modules attaches characters to players
   - Combat modifications applied through character components

## Recommendations for Combat Development
1. Keep combat logic primarily server-side for security
2. Use client-side prediction for responsive feel, with server reconciliation
3. Centralize combat constants and formulas in shared configs
4. Modularize skills for easy addition of new abilities
5. Implement proper hit validation to prevent exploits