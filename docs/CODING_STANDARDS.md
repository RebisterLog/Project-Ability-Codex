# PAC Coding Standards & Project Principles

This document defines the coding conventions, architecture principles, and patterns used throughout the PAC (Project Adventure Combat) Roblox game project. Follow these conventions when adding or modifying code.

---

## 1. Luau Conventions

### Pragmas

All server combat code should use performance pragmas at the top of the file:

```luau
--!native
--!optimize 2
```

Type-checked modules use:

```luau
--!strict
```

### Type Exports

Public types are defined in `src/server/types.luau` and exported with `export type`:

```luau
export type SkillData = {
    Id: string,
    Cooldown: number,
    DisplayName: string,
    ...
}
```

### Type Annotations

- All function parameters must have type annotations
- Return types should be annotated on public functions
- Cast with `:: TypeName` where inference is ambiguous
- Use `typeof()` for complex inferred types (e.g. `typeof(CombatService)`)

---

## 2. Naming Conventions

| Scope | Convention | Example |
|---|---|---|
| Module/Class names | PascalCase | `Skill.luau`, `CombatService`, `Spec` |
| Variable/function names | camelCase | `self.AlreadyHit`, `GetDashDirection()` |
| Constants | PascalCase or UPPER_CASE | `Enums.Stun.Heavy`, `MOVEMENT_ANIMATIONS` |
| File names | PascalCase (classes), camelCase (utilities) | `SkillService.luau`, `pathUtil.luau` |
| Type names | PascalCase | `types.SkillData`, `types.AttackInfo` |
| Private fields | PascalCase (table keys) | `self.Sequence`, `self.GrabData` |
| Service methods | PascalCase | `CombatService:Hitbox()`, `CombatService:Attack()` |

---

## 3. Module Pattern

Every module returns a single value (table, class, or function):

```luau
-- Skill module (returns a data table)
local Skill: types.SkillData = {
    DisplayName = "MySkill",
    ...
}
function Skill.onInit(self) end
function Skill.Activate(self) end
function Skill.Interrupt(self) end
return Skill

-- Service module (returns a service table)
local MyService = Crane:CreateService({ Name = "MyService" })
function MyService:onStart() end
return MyService
```

### Method Call Convention

Two call conventions coexist:

```luau
-- Convention 1: colon syntax (used by Skill.luau, services)
function Skill:Activate() end      -- self is implicit
skill:Activate()

-- Convention 2: dot syntax with explicit self (used by some skills)
function Skill.Activate(self) end  -- self is explicit
Skill.Activate(self)
```

Both are valid. Colon syntax is preferred for new code. When editing existing code, match the file's existing convention.

---

## 4. Crane Framework Patterns

### Services

Services are global singleton modules managed by Crane. Created with `Crane:CreateService`.

```luau
-- Definition
local CombatService = Crane:CreateService({
    Name = "CombatService",
})

-- Lifecycle methods
function CombatService:onInit()
    -- Called when service is first loaded (before onStart)
end

function CombatService:onStart()
    -- Called after all services are loaded
    -- Access other services here
    self.VFXService = Crane:GetService("VFXService")
end

-- Access from anywhere
local svc = Crane:GetService("CombatService")
```

### Components

Components are attached to Roblox instances. Created with `Crane:CreateComponent`.

```luau
local Character = Crane:CreateComponent({ Name = "Character" })

function Character.onStart(self)
    -- self.instance is the Roblox Instance this component is attached to
    self.Humanoid = self.instance:WaitForChild("Humanoid")
    self.RootPart = self.instance:WaitForChild("HumanoidRootPart")
end

-- Access from script
local component = Crane:GetComponent("Character", characterInstance)
```

### Signals (`Crane.Signal`)

```luau
local Signal = Crane.Signal
self.Attacked = Signal()
self.Attacked:Connect(function(Type, Data)
    -- handle event
end)
self.Attacked:Fire("Precast", attackData)
```

### Packets (Remote Events/Functions)

Client-server communication via `Crane:GetPacket`:

```luau
-- Server listens:
Crane:GetPacket("StartSkill").listen(function(skillId, player)
    -- handle
end)

-- Client fires (implied):
-- Crane:GetPacket("StartSkill").fire(skillId)
```

---

## 5. Cleanup Pattern (Janitor / Buttler)

All resources must be properly cleaned up. Use `Crane.Janitor` for managing cleanup.

```luau
local Janitor = Crane.Janitor

-- Option 1: Janitor (scoped cleanup)
self.Janitor = Janitor.new()
self.Janitor:Add(object, "Destroy")      -- Calls :Destroy() on cleanup
self.Janitor:Add(function() end)         -- Calls function on cleanup
self.Janitor:Destroy()                    -- Clean everything

-- Option 2: Buttler (keyed cleanup, used by Character component)
self.Cleaner = Crane.Buttler.new()
self.Cleaner:Add(object)                 -- Auto-detect Dispose/Destroy
self.Cleaner:Set("Spec", spec, "Destroy") -- Keyed — replaces existing
self.Cleaner:Remove("Spec")               -- Remove by key
self.Cleaner:Destroy()                    -- Clean everything
```

**Always clean up:**
- Sequence objects added to `self.Janitor:Add(...)`
- Parameters added via `seq.Cleaner:Add(character:AddParameter(...))`
- VFX effects stopped on interrupt
- Event connections

---

## 6. Proxy Pattern (Reactive Data)

Proxy is used to sync skill/spec state between server and client reactively.

```luau
-- Server creates a proxy
self.Proxy = Proxy({
    Skills = {}
})

-- Patch to update
self.Proxy:Patch({
    {Name = "SetDictionary", Path = {"Skills"}, Args = {skillId, skill.Proxy()}}
})

-- Subscribe to changes
skill.Proxy:Subscribe("AnyChange", {"Parameters"}, function(data)
    -- React to changes
end)

-- Read current value
local state = self.Proxy()
print(state.Skills)
```

---

## 7. Sequencer (Frame-Based Animation)

Sequencer drives frame-based animation sequences for combat skills.

```luau
local Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)

self.Sequence = CombatService.CreateSequence(character, {
    -- Optional validation callback
    Validate = function() return true end,

    Frames = {
        -- { frameNumber, callback }
        -- { frameNumber, callback, loopEndFrame }
        {0, function(seq)
            seq.Cleaner:Add(...)    -- Scoped cleanup (destroyed when sequence stops)
            seq.Cleaner:Set(...)    -- Keyed (replaces existing by key)
            seq.Cleaner:Remove(...) -- Remove by key
            seq.Speed               -- Current animation speed (adjusted by Timescale)
        end},
        {30, function() end, 45},   -- Loops frames 30-45
        {60}                        -- End frame (no callback)
    }
})

-- Control
self.Sequence:Play()
self.Sequence:Await()              -- Yields until sequence finishes
self.Sequence:Stop()
self.Sequence:AdjustSpeed(multiplier)
self.Sequence:IsPlaying()          -- Check if running
self.Sequence.CurrentFrame         -- Current frame number
```

---

## 8. Attack Hook System

Combat attacks flow through a Hook pipeline with three phases:

```luau
self.AttackHook = Hook.new("Attack", {"Precast", "Cast", "Postcast"})

-- Precast: before anything (validate, fire Attacked signal)
-- Cast: apply hit effects
-- Postcast: finalize (return result)
```

Each hook callback receives `AttackData` and must return `true` to continue or `false`/`nil` to abort.

Hooks can be added via:

```luau
-- From another module (auto-loaded from CombatService/Hooks/*)
self.AttackHook:Hook("Precast", "MyHook", priority, function(Data)
    -- Custom logic
    return true
end)
```

---

## 9. AttackData State Machine

Every attack resolves to a state table with the following fields:

| State | Set when | Meaning |
|---|---|---|
| `Success` | Always | `true` if hit connects (not IFrame, not dead) |
| `Continue` | Always | `true` if follow-up/chaining is allowed |
| `Blocking` | Target is holding block | Target's defensive state |
| `Blocked` | Hit lands on block | Attack was blocked |
| `BlockBroken` | Block health exceeded | Target's block is broken, vulnerable |
| `BlockCanceled` | Attack cancels block | Block is nullified by the attack |
| `PerfectBlocking` | Target in perfect block window | Target is frame-perfect blocking |
| `PerfectBlocked` | Perfect block succeeds | Attacker is punished instead |
| `BlockIgnored` | Attack bypasses block | e.g. grab attacks |
| `IFrames` | Target has i-frames | `number` level of invincibility |
| `Armored` | Target has super armor | `true` if armor active |

### State examples from the codebase (`src/server/types.luau:165-229`):

```
Normal hit:     { Success: true, Continue: true, Blocking: false, Blocked: false, ... }
Normal block:   { Success: true, Continue: true, Blocking: true, Blocked: true, ... }
Block break:    { Success: true, Continue: true, Blocking: true, Blocked: true, BlockBroken: true }
Perfect block:  { Success: true, Continue: false, Blocking: true, Blocked: true, PerfectBlocking: true, PerfectBlocked: true }
Block cancel:   { Success: true, Continue: true, Blocking: true, Blocked: false, BlockCanceled: true }
```

---

## 10. AttackInfo Structure

Comprehensive reference of all `AttackInfo` fields (all optional):

```luau
AttackInfo = {
    Priority = number?,           -- Attack priority for trade logic
    Damage = number?,             -- Raw damage value
    Block = {
        Blockable = true?,        -- Can be blocked
        PerfectBlockable = false?,-- Can be perfect-blocked
        BlockBreak = false?,      -- Breaks the target's block
        BlockCancel = false?,     -- Cancels block entirely
        BlockIgnore = false?,     -- Ignores block (grab)
    },
    Stun = {
        Duration = number,        -- Seconds of stun
        Priority = Enums.Stun.*,  -- Light=10, Medium=20, Heavy=30
    },
    Knockback = {
        RelativePart = "Attacker" | "Target",  -- Knockback relative to who
        RelativeTowards = "Attacker" | "Target"?,
        ToFront = number? | false?,             -- Pull target toward attacker
        Origin = CFrame?,
        Speed = number,
        Duration = number,
        Velocity = Vector3?,
        MaxForce = Vector3?,
        FindCrashObject = false?,              -- Calculate crash trajectory
    },
    Angular = {
        Velocity = Vector3,       -- Angular velocity
        Speed = number?,
        Duration = number?,
        MaxTorque = number?,
    },
    Ragdoll = {
        Duration = number,        -- Seconds of ragdoll
    },
}
```

---

## 11. Combat Enums

```luau
return {
    IFrames = {
        Ragdoll = 10,
        Dodge = 15,
        Grab = 50,
        True = 10000,
    },
    Stun = {
        None = 0,
        Light = 10,
        Medium = 20,
        Heavy = 30,
    },
}
```

---

## 12. Skill Lifecycle Flow

```
Player input on client
  → Client sends packet: Crane:GetPacket("StartSkill").fire(skillId)
  → Server SkillService.onStart listens:
      Crane:GetPacket("StartSkill").listen(function(skillId, player)
          → Gets character component
          → Gets spec from component
          → spec:ActivateSkill(skillId)
              → Validates skill (cooldown, stun, ragdoll, alive)
              → Calls Skill:Activate()
                  → Skill plays its sequence / promise
                  → Sequence fires hitbox checks on specified frames
                  → CombatService:Attack() processes each hit
                      → Gets target states (blocking, perfect blocking, armor, IFrames)
                      → Runs AttackHook pipeline (Precast → Cast → Postcast)
                      → Fires Attacked signal
                  → VFX replicated to clients
      )
  → Server sends updates via proxy replication
  → Client reacts to proxy changes (UI, VFX)
```

---

## 13. Service Dependency Graph

```
SkillService
  └─ depends on: SpecService, PathUtil
  └─ provides: Skill loading, creation, packet handling

SpecService
  └─ depends on: ConfigService, SkillService
  └─ provides: Spec creation, skill binding

CombatService
  └─ depends on: VFXService
  └─ provides: Hitbox, Attack, CreateSequence, CreateGrab, AddArmor, GetStates
  └─ signals: Casted (Hitbox), Attacked (Attack), Interrupted
  └─ hooks: AttackHook (Precast, Cast, Postcast)

CollisionService
  └─ provides: Collision group registration and assignment

PlayersService
  └─ provides: Player management

VFXService (server)
  └─ provides: StartEffect, StopEffect (Animation, Sound, Particle, Highlight, Hitbox, Ragdoll)

ConfigsService
  └─ provides: Config loading (Specs, Skins, etc.)
```

---

## 14. File Structure

```
src/
├── client/                     # Runs on player devices
│   ├── components/             # Client-side components (Character, Player)
│   ├── controls/               # Input handling (Keyboard, Mobile, JoystickBinds)
│   ├── services/               # Client services (Bind, Chrono, Player, TargetLock, UI, VFX)
│   └── ui/                     # UI components
│
├── server/                     # Runs on game server
│   ├── combat-classes/         # Core classes (Skill, Spec, Hook)
│   ├── components/             # Server components (Character, Player)
│   ├── player-modules/         # Player modules (CharacterAdder, SpecModule)
│   ├── services/               # Server services (Combat, Skill, Spec, Collision, etc.)
│   ├── skills/                 # Skill implementations (*.luau + character subfolders)
│   ├── specs/                  # Spec definitions (*.luau)
│   ├── Enums.luau              # Game enums
│   ├── types.luau              # All public type definitions
│   └── runtime.legacy.luau     # Legacy runtime code
│
└── shared/                     # Shared between client/server
    ├── configs/                # Configs (Specs, Skins, Bots, Chrono)
    ├── effects/                # VFX implementations (Animation, Sound, Hitbox, etc.)
    ├── packages/               # Libraries (Crane, Fusion, Janitor, Proxy, Sequencer, etc.)
    └── schemas/                # Data schemas (PlayerData, GameData, etc.)
```

---

## 15. Performance Principles

1. **Combat logic is server-authoritative** — all damage, hit detection, and state changes happen on the server
2. **Client-side prediction** for responsive feel, with server reconciliation
3. **Reactive replication** via Proxy — only changed data is synced
4. **Object pooling** for particle effects and temporary instances
5. **Janitor cleanup** to prevent memory leaks — every spawned resource must be tracked
6. **`--!native` and `--!optimize 2`** on performance-critical server files
7. **Spatial queries use Roblox physics** (`GetPartBoundsInBox`/`GetPartBoundsInRadius`) — not custom overlap logic
8. **Frame-based sequences** for precise animation timing at 60fps
