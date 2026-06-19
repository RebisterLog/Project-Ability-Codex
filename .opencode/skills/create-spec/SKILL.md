---
name: create-spec
description: Generate spec modules and associated assets for PAC characters
---

# Create Spec

Instructs the AI to generate a new spec module (`src/server/specs/*.luau`) and its associated assets for the PAC project.

---

## Overview

A "spec" (specification) is a character's skill set, visual assets, and configuration bundled together. Each spec defines what skills a character has, how they animate, what sounds they make, and what models they use.

Creating a spec involves **4 files** (and a directory of assets in ReplicatedStorage):

```
src/server/specs/Name.luau              — Spec module (skill list, onInit)
src/shared/configs/Skins/Name/None.luau — Skin config (animations, sounds, models, stats)
src/shared/configs/Specs.luau            — Config (display name, binds, visibility)
ReplicatedStorage.assets.Name.None/      — Animation/Sound/Model instances
```

---

## 1. Spec Module (`src/server/specs/Name.luau`)

The spec module maps skill IDs to skill module paths and defines an optional `onInit` for attaching models.

### Minimal template:

```luau
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Configuration = ServerScriptService.server.Configuration
local Configs = Configuration.ConfigsFolder.Value
local SpecsConfig = require(Configs.Specs)
local skills = ServerScriptService.server.skills

local Spec = {
    Skills = {
        ["Dash"]  = "~/skills/Dash",
        ["Punch"] = "~/skills/Punch",
        ["Block"] = '~/skills/Block',
        ["Run"]   = "~/skills/Run",
        ["Grab"]  = "~/skills/Grab",

        ["UniqueSkill"] = "@Specs/Name/UniqueSkill",
    },

    onInit = function(self)
        -- Optional: attach weapon models to character
    end,
}

return Spec
```

### Skill path rules:

| Prefix | Meaning | Example | File Location |
|---|---|---|---|
| `~/skills/` | Shared skill (any spec can use) | `"~/skills/Dash"` | `src/server/skills/Dash.luau` |
| `@Specs/Name/` | Character-unique skill | `"@Specs/Undyne/ArcSpearStrike"` | `src/server/skills/Undyne/ArcSpearStrike.luau` |

### `onInit(self)` — Weapon/Model Attachment

Commonly used to clone and weld a weapon model to the character rig:

```luau
onInit = function(self)
    -- Get the weapon model from spec skin config
    local weapon = self.Data.Assets.Models["WeaponName"] :: Model

    if weapon then
        local copy = weapon:Clone()
        copy:PivotTo(self.Character.instance:GetPivot())

        -- Weld to the character's arm
        local motor = Instance.new("Motor6D")
        motor.Name = "HandleMotor"
        motor.Part0 = self.Character.instance:FindFirstChild("Right Arm")
        motor.Part1 = copy:FindFirstChild("Handle")
        motor.C0 = CFrame.new(0, -1, 0)
        motor.Parent = copy

        copy.Parent = self.Character.instance
    end
end,
```

**Real examples:**
- **Gerson** (`src/server/specs/Gerson.luau:21-33`): Clones `Hammer` model, uses existing Motor6D from the model, sets `Part0` to `Right Arm`
- **Undyne** (`src/server/specs/Undyne.luau:22-38`): Clones `Spear`, creates new Motor6D, welds to `Right Arm` via `Handle`
- **Standless** (`src/server/specs/Standless.luau:20-22`): No models, empty `onInit`

---

## 2. Skin Config (`src/shared/configs/Skins/Name/None.luau`)

The skin config defines what animations, sounds, models, and stats a spec uses. Each spec can have multiple skins (e.g. default, alt, premium). The skin system is auto-loaded by `src/shared/configs/Skins/init.luau`.

### Template:

```luau
local Assets = game:GetService("ReplicatedStorage").assets
local GlobalAnimations = Assets.Default

local Animations = Assets.Name.None.Animations
local Sounds = Assets.Name.None.Sounds
local Models = Assets.Name.None.Models

local None = {
    Animations = {
        -- Movement (REQUIRED — set automatically by Spec.Init)
        Idle = {
            Animation = Animations.User.Movements.Idle,
            Priority = Enum.AnimationPriority.Idle,
        },
        Walk = {
            Animation = Animations.User.Movements.Walk,
            Priority = Enum.AnimationPriority.Movement,
        },
        Run = {
            Animation = Animations.User.Movements.Run,
            Priority = Enum.AnimationPriority.Movement,
        },

        -- Block
        Block = {
            Animation = Animations.User.Block,
            Priority = Enum.AnimationPriority.Action,
        },

        -- Dash (4 directions)
        DashForward = {
            Animation = GlobalAnimations.Dash.Forward,
            Priority = Enum.AnimationPriority.Action,
        },
        DashBack = {
            Animation = GlobalAnimations.Dash.Backward,
            Priority = Enum.AnimationPriority.Action,
        },
        DashLeft = {
            Animation = GlobalAnimations.Dash.Left,
            Priority = Enum.AnimationPriority.Action,
        },
        DashRight = {
            Animation = GlobalAnimations.Dash.Right,
            Priority = Enum.AnimationPriority.Action,
        },

        -- Punches (4-hit combo)
        Punch1 = {
            Animation = Animations.Punches.Punch1,
            Priority = Enum.AnimationPriority.Action,
        },
        Punch2 = {
            Animation = Animations.Punches.Punch2,
            Priority = Enum.AnimationPriority.Action,
        },
        Punch3 = {
            Animation = Animations.Punches.Punch3,
            Priority = Enum.AnimationPriority.Action,
        },
        Punch4 = {
            Animation = Animations.Punches.Punch4,
            Priority = Enum.AnimationPriority.Action,
        },

        -- Grab (two variants: StandOff and StandOn)
        StandOffGrab = {
            Animation = Animations.User.GrabStart,
            Priority = Enum.AnimationPriority.Action,
        },
        StandOffThrow = {
            Animation = Animations.User.GrabHit,
            Priority = Enum.AnimationPriority.Action,
        },
        StandOffThrowVictim = {
            Animation = Animations.Enemy.Grab,
            Priority = Enum.AnimationPriority.Action,
        },
        StandOnGrab = {
            Animation = Animations.User.GrabStart,
            Priority = Enum.AnimationPriority.Action,
        },
        StandOnThrow = {
            Animation = Animations.User.GrabHit,
            Priority = Enum.AnimationPriority.Action,
        },
        StandOnThrowVictim = {
            Animation = Animations.Enemy.Grab,
            Priority = Enum.AnimationPriority.Action,
        },

        -- Character-specific skills
        -- SkillName = {
        --     Animation = Animations.User.SkillName,
        --     Priority = Enum.AnimationPriority.Action,
        -- },
    },

    Sounds = {
        -- Punch sounds (one per combo step)
        Punch1 = { Sound = Sounds.Punches.Punch1, Volume = 1 },
        Punch2 = { Sound = Sounds.Punches.Punch2, Volume = 1 },
        Punch3 = { Sound = Sounds.Punches.Punch3, Volume = 1 },
        Punch4 = { Sound = Sounds.Punches.Punch4, Volume = 1 },

        -- Grab sounds
        StandOffGrab    = { Sound = Sounds.GrabStart, Volume = 1 },
        StandOffGrabbed = { Sound = Sounds.GrabHit, Volume = 1 },
        StandOffGrabVL  = { Sound = Sounds.GrabVoice, Volume = 1 },

        -- Character-specific skill sounds
        -- SkillName      = { Sound = Sounds.SkillName, Volume = 1 },
    },

    Models = {
        -- Shared
        PunchHit = Models.PunchHit,

        -- Character-specific models
        -- WeaponName = Models.WeaponName,
    },

    Stats = {
        Grab = {
            AnimationOffset  = CFrame.new(0, 0, -4) * CFrame.Angles(0, math.pi, 0),
            StartHitFrame    = 30,
            EndHitFrame      = 40,
            FinalFrame       = 75,
        },
    },
}

return None
```

### Animation naming conventions:

| Category | Names | Notes |
|---|---|---|
| Movement | `Idle`, `Walk`, `Run` | **Required** — set as attributes by `Spec.Init` |
| Punches | `Punch1`...`Punch4` | 4-step combo |
| Dash | `DashForward`, `DashBack`, `DashLeft`, `DashRight` | 4 directions |
| Block | `Block` | Single blocking animation |
| Grab (user) | `StandOffGrab`, `StandOffThrow` | Grab start + throw |
| Grab (victim) | `StandOffThrowVictim`, `StandOnThrowVictim` | Victim response |
| Unique | Any string | Skill-specific, referenced by `self.Data.Assets.Animations["Name"]` |

### Sound naming conventions:

| Pattern | Example |
|---|---|
| `Punch1`...`Punch4` | Per-hit sounds |
| `SkillName` | Default sound |
| `SkillNameVL` | Voice line |
| `SkillNameHit` | Hit impact sound |
| `StandOffGrab`, `StandOffGrabbed`, `StandOffGrabVL` | Grab sounds |

### Animation Priority:

- `Enum.AnimationPriority.Idle` — Idle/Walk
- `Enum.AnimationPriority.Movement` — Run
- `Enum.AnimationPriority.Action` — All combat animations

### Sound fields:

- `Sound` — The Sound instance
- `Volume` — Volume multiplier (0-1, optional, default likely 1)
- `PlaybackSpeed` — Speed multiplier (optional)

### Model entries:

Direct references to Model or BasePart instances in `ReplicatedStorage.Assets`.

### Stats.Grab fields:

| Field | Type | Description | Default |
|---|---|---|---|
| `AnimationOffset` | `CFrame` | Offset for the grab bind | `CFrame.new(0,0,-4) * CFrame.Angles(0, math.pi, 0)` |
| `StartHitFrame` | `number` | Frame when grab hitbox activates | `30` |
| `EndHitFrame` | `number` | Frame when grab hitbox deactivates | `40` |
| `FinalFrame` | `number` | Frame when throw occurs | `30` (Standless), `75` (Gerson, Undyne) |

---

## 3. Config Registration (`src/shared/configs/Specs.luau`)

Each spec needs an entry here with display info and default keybinds.

```luau
local Specs = {
    ["Name"] = {
        DisplayName = "Name",
        IsPublic = true,

        Binds = {
            ["Dash"]              = Enum.KeyCode.C,
            ["Block"]             = Enum.KeyCode.F,
            ["Punch"]             = Enum.UserInputType.MouseButton1,
            ["Run"]               = Enum.KeyCode.LeftControl,
            ["Grab"]              = Enum.KeyCode.X,

            ["UniqueSkill"]       = Enum.KeyCode.E,
            ["AnotherSkill"]      = Enum.KeyCode.R,
        }
    },
}
```

### Bind types:
- `Enum.KeyCode.X` — Keyboard keys
- `Enum.UserInputType.MouseButton1` — Mouse buttons
- `Enum.UserInputType.Touch` — Touch input

---

## 4. Asset Directory Convention

Assets live in `ReplicatedStorage.assets`:

```
ReplicatedStorage/
└── assets/
    └── Name/                    -- Matches spec name
        └── None/                -- Skin name (at least "None")
            ├── Animations/
            │   └── User/
            │       ├── Movements/
            │       │   ├── Idle (<Animation>)
            │       │   ├── Walk
            │       │   └── Run
            │       ├── Punches/
            │       │   ├── Punch1
            │       │   ├── Punch2
            │       │   ├── Punch3
            │       │   └── Punch4
            │       ├── GrabStart
            │       ├── GrabHit
            │       └── ... (skill animations)
            ├── Music/
            ├── Sounds/
            │   ├── Punches/
            │   │   ├── Punch1
            │   │   └── ...
            │   └── ... (skill sounds)
            └── Models/
                ├── PunchHit
                └── ... (weapon/cosmetic models)
```

---

## Lifecycle Summary

When a character is created or changes spec:

1. **Character.SetSpec** (`src/server/components/Character/init.luau:124`) calls `SpecService:CreateSpec`
2. **SpecService.CreateSpec** (`src/server/services/SpecService.luau:25`):
   - Loads spec data from config (`ConfigService:Get("Specs")[spec.Id]`)
   - Loads skin data (`ConfigService:Get("Skins")[spec.Id][skinName]`)
   - Merges config + module data → `SpecData`
   - Loads each skill via `SkillService:CreateSkill`
   - Calls `spec:AddSkill(skill)` for each skill
   - Assigns binds
   - Calls `spec:Init()`
3. **Spec.Init** (`src/server/combat-classes/Spec.luau:9`):
   - Sets movement animations (`Idle`, `Walk`, `Run`) as character attributes
   - Calls `self.Data.onInit(self)` — the spec module's `onInit`
4. Each **Skill.Init** (`src/server/combat-classes/Skill.luau:91`):
   - Calls `self.Data.onInit(self)` — the skill module's `onInit`
   - Connects to `CombatService.Interrupted` if the skill has an `Interrupt`
