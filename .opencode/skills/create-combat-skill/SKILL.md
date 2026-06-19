---
name: create-combat-skill
description: Generate combat skill modules following PAC project architecture
---

# Create Combat Skill

Instructs the AI to generate a new combat skill module (`src/server/skills/*.luau`) following the PAC project's architecture.

---

## Overview

Skills are the atomic combat actions in PAC. They are **highly variable** — there is no rigid template. Every skill defines its own structure, data fields, and execution flow. The only commonality is that each skill module returns a table conforming (loosely) to `types.SkillData`.

```luau
-- Minimal valid skill (Run.luau)
local Skill = {
    DisplayName = "Run",
}
function Skill.Activate(self)
    -- toggle walk speed
end
return Skill
```

```luau
-- Full-featured skill (Barrage.luau)
local Skill: types.SkillData = {
    DisplayName = "Barrage",
    Cooldown = 2,
    SkillCharacters = { "Hit", "ComboExtender", "Blockable" },
    PreBarrageInfo = { ... },
    BarrageInfo = { ... },
    PostBarrageInfo = { ... },
}
function Skill.onInit(self) ... end
function Skill.Activate(self) ... end
function Skill.Interrupt(self) ... end
return Skill
```

---

## Comment Block Requirement

Before the `local Skill` declaration, you MUST include a block comment documenting the skill's purpose and all assets it uses, following this format:

```luau
--[=[ SKILL_NAME

   Short description of the skill, what it does, and when it's used.


   ASSETS:

   Animations
      AnimName : Animation for [action]

   Sounds
      SoundName : Sound for [effect]

   Models
      ModelName : (BasePart) VFX part for [purpose]

   Stats
      StatName : Description (CFrame, Vector3, Color3, number, etc.)
]=]

local Skill = {
    ...
```

Include **all** assets the skill references so developers can verify the spec's skin config provides them. Omit any asset category that isn't used.

---

## SkillData Contract — What's Guaranteed vs What's Freeform

### Fields defined by `types.SkillData` (the "contract"):

| Field | Type | Required? | Notes |
|---|---|---|---|
| `DisplayName` | `string` | Yes | Human-readable skill name |
| `Id` | `string` | Set by SkillService | Auto-assigned from module name |
| `Cooldown` | `number` | No | Seconds before skill can be used again |
| `AttackInfo` | `types.AttackInfo` | No | Optional — see AttackInfo section below |
| `SkillCharacters` | `{string}` | No | Arbitrary tags for categorizing the skill |
| `onInit` | `(self: Skill) -> ()` | No | Called once when skill is first added to spec |
| `Activate` | `(self: Skill) -> ()` | No | Called when skill fires |
| `Interrupt` | `(self: Skill) -> ()` | No | Called when skill is interrupted (stun, etc.) |

### **Everything else is skill-defined private data.**

There is no fixed schema. Each skill adds whatever fields it needs:

- **Punch.luau** adds: `ComboCooldown`, `ComboResetTime`, `MaxCombo`
- **Dash.luau** adds: `DashProperties { Speed, Time }`
- **Barrage.luau** adds: `PreBarrageInfo`, `BarrageInfo`, `PostBarrageInfo`
- **Grab.luau** adds: `OnGrab`, `OnThrow`, `Throw { ... }`, `AttackInfo`
- **Block.luau** adds: nothing beyond the base contract (minimal)

When creating a new skill, **analyze existing skills for the closest analog** rather than forcing a template.

---

## Lifecycle Methods — All Optional

### `onInit(self)`

Called once when the skill is constructed (inside `Spec:AddSkill`). Use for setup that needs access to `self.Character` and `self.Spec`.

**Common patterns inside onInit:**

1. **Get services** via `Crane:GetService("ServiceName")`:
   ```luau
   local VFXService = Crane:GetService("VFXService")
   local CombatService = Crane:GetService("CombatService")
   ```

2. **Access spec assets** for this skill:
   ```luau
   local Anims = self.Spec.Data.Assets.Animations
   local Sounds = self.Spec.Data.Assets.Sounds
   local Models = self.Spec.Data.Assets.Models
   ```

3. **Initialize state**:
   ```luau
   self.AlreadyHit = {}
   self.PunchCount = 1
   ```

4. **Create a sequence** (most common pattern):
   ```luau
   self.Sequence = self.Janitor:Add(CombatService.CreateSequence(character, {
       Frames = { ... }
   }))
   ```

**Skills that skip onInit entirely:** Block.luau, Run.luau

### `Activate(self)`

Called when the player triggers the skill (after validation passes).

**Patterns seen in real code:**

| Pattern | Used by | Notes |
|---|---|---|
| Play sequence and await | Most skills | `self.Sequence:Play()` → `self.Sequence:Await()` |
| Toggle a state | Run.luau | Just toggles `MinWalkSpeed` parameter |
| Promise with signals | Block.luau | Uses `Promise.new()` with `self.Deactivated:Once(resolve)` |
| Multi-sequence management | Grab.luau | Plays `Sequence`, then may play `GrabSequence` |

### `Interrupt(self)`

Called when the character is stunned, ragdolled, or otherwise interrupted during the skill.

**Common cleanup:**
```luau
if self.Sequence then self.Sequence:Stop() end
VFXService:StopEffect(Players:GetPlayers(), "Animation", character.instance, {
    Animation = Anims["SkillName"].Animation,
})
```

**Skills that skip Interrupt:** Run.luau (no cleanup needed)

---

## Sequence Pattern (Most Common)

Frame-based animation sequence using `CombatService.CreateSequence`.

```luau
self.Sequence = self.Janitor:Add(CombatService.CreateSequence(character, {
    Frames = {
        -- { frameNumber, callback }
        -- Optionally: { frameNumber, callback, loopEndFrame } for looping sections
        {0, function(seq)
            -- Setup: parameters, animations, sounds
            seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 3))
            seq.Cleaner:Add(character:AddParameter("MaxJumpPower", 0))

            VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, {
                Animation = Anims["SkillName"],
                Speed = seq.Speed,
            })
            VFXService:StartEffect(Players:GetPlayers(), "Sound", RootPart, Sounds["SkillName"])

            -- Cleanup on sequence end/interrupt
            seq.Cleaner:Add(function()
                VFXService:StopEffect(Players:GetPlayers(), "Animation", character.instance, {
                    Animation = Anims["SkillName"].Animation,
                })
            end)
        end},

        {15, function(seq)
            -- Hitbox check + attack at this frame
            local Targets = CombatService:Hitbox({
                Skill = self,
                Caster = character,
                Info = AttackInfo.Hitbox,
            })

            for _, Target in Targets do
                if table.find(self.AlreadyHit, Target) then continue end

                CombatService:Attack({
                    Attacker = character,
                    Victim = Target,
                    Info = AttackInfo,
                }):andThen(function(Data: types.AttackData)
                    if not Data.State.Success then return end
                    table.insert(self.AlreadyHit, Target)
                end)
            end
        end, 20}, -- loopEndFrame = 20 means runs frames 15-20 repeatedly

        {45} -- End frame
    }
}))
```

### Cleaner API inside sequences:

| Method | Usage | Description |
|---|---|---|
| `seq.Cleaner:Add(object)` | Add cleanup callback or Janitor-managed object | Destroyed when sequence stops/ends |
| `seq.Cleaner:Set(key, object)` | Like Add but keyed (replaces existing) | Overwrite without duplicate |
| `seq.Cleaner:Remove(key)` | Remove a keyed object early | Release before sequence ends |

### Sequence validation (optional):

```luau
self.GrabSequence = self.Janitor:Add(CombatService.CreateSequence(character, {
    Validate = function()
        return self.Target.Parent and character.instance.Parent
    end,
    Frames = { ... }
}))
```

### Alternative: Promise-based flow (no sequence)

Used by Block.luau. Attach to signals, resolve when done:

```luau
function Block:Activate()
    local Collector = Crane.Janitor.new()
    Promise.new(function(resolve)
        Collector:Add(self.Deactivated:Once(resolve))
        Collector:Add(CombatService.Attacked:Connect(function(Type, Data)
            if Type == "Precast" and Data.Victim == character then
                -- handle block states
            end
        end))
    end):finallyCall(Collector.Destroy, Collector):await()
end
```

---

## CombatService API

### `CombatService:Hitbox(data: HitboxData): {Character}`

Performs a spatial query to find hit targets.

```luau
local targets = CombatService:Hitbox({
    Skill = self,       -- Optional: fires Casted signal if set
    Caster = character, -- Required
    Info = {
        Size = Vector3.new(7, 7, 7),  -- Vector3 for box, number for sphere radius
        Offset = CFrame.new(0, 0, -3), -- Offset from caster RootPart
        Origin = CFrame?,              -- Override origin (defaults to RootPart.CFrame)
        SortByDistance = true?,        -- Sort targets nearest-first
        CanQueryCaster = false?,       -- Allow hitting self
        Parameters = OverlapParams?,   -- Custom overlap params
        Debug = true?,                 -- Visualize hitbox via VFX
    }
})
```

**Size types:**
- `Vector3` → `GetPartBoundsInBox`
- `number` → `GetPartBoundsInRadius`

### `CombatService:Attack(data: AttackData): Promise<AttackData>`

Registers an attack on a target. Returns a Promise that resolves with the attack result.

```luau
CombatService:Attack({
    Attacker = character,
    Victim = target,
    Info = {
        Damage = 15,
        Block = {
            Blockable = true?,     -- Can be blocked
            PerfectBlockable = false?,
            BlockBreak = false?,   -- Breaks blocking target's guard
            BlockCancel = false?,  -- Cancels the block entirely
            BlockIgnore = false?,  -- Ignores block (grab)
        },
        Stun = {
            Duration = 0.7,
            Priority = Enums.Stun.Medium,  -- Light=10, Medium=20, Heavy=30
        },
        Knockback = {
            RelativePart = "Attacker" | "Target",
            ToFront = number? | false?,
            Speed = 40,
            Duration = 0.1,
            Velocity = Vector3.new(0, 50, 0)?,
            FindCrashObject = false?,
        },
        Ragdoll = {
            Duration = 2,
        },
        Angular = {
            Velocity = Vector3.new(-15, 0, 0),
            Duration = 0.2,
        },
    },
}):andThen(function(Data)
    if Data.State.Success then
        -- Hit connected
        if Data.State.Continue then
            -- Allowed to continue combo
        end
        if Data.State.Blocked then
            -- Target was blocking
        end
        if Data.State.BlockBroken then
            -- Target's block was broken
        end
        if Data.State.PerfectBlocked then
            -- Attacker was perfect-blocked (attacker gets punished)
        end
    end
end)
```

### `AttackData.State` fields:

| Field | Type | Meaning |
|---|---|---|
| `Success` | bool | Hit registered (not miss, IFrame, dead) |
| `Continue` | bool | Attack chain can continue |
| `Blocking` | bool | Target was holding block |
| `Blocked` | bool | Hit landed on block |
| `BlockBroken` | bool | Block was broken by this hit |
| `BlockCanceled` | bool | Block was canceled entirely |
| `PerfectBlocking` | bool | Target was in perfect block window |
| `PerfectBlocked` | bool | Attacker got punished by perfect block |
| `BlockIgnored` | bool | Attack ignores block (grab) |
| `IFrames` | number | Target's IFrame level |
| `Armored` | bool | Target has super armor |

---

## Character Parameters (`character:AddParameter` / `character:GetParameter`)

Parameters are layered (stacked) — multiple sources can add the same parameter, newest takes priority, removed when the source is destroyed.

```luau
-- Add a parameter (returns an object with .Destroy())
local walkMod = character:AddParameter("MaxWalkSpeed", 3)
-- Later: walkMod:Destroy() to remove it

-- Commonly used parameters:
character:AddParameter("MaxWalkSpeed", value)    -- Movement speed cap
character:AddParameter("MaxJumpPower", value)    -- Jump power cap
character:AddParameter("IFrames", Enums.IFrames.Ragdoll)  -- Invincibility frames
character:AddParameter("Stun", {Duration = 1, Priority = Enums.Stun.Heavy})
character:AddParameter("Armor", true)            -- Super armor
character:AddParameter("Timescale", 1.5)         -- Animation speed multiplier
character:AddParameter("Ragdoll", true)          -- Force ragdoll state
character:AddParameter("Restrain", true)         -- Disable movement
character:AddParameter("NoCollision", true)      -- Disable collision
character:AddParameter("MinWalkSpeed", 25)       -- Minimum movement speed
```

```luau
-- Check a parameter
local currentSpeed = character:GetParameter("MaxWalkSpeed")
local stunDuration = character:GetParameter("Stun").Duration
```

---

## VFXService API

```luau
-- Start an effect (replicated to a set of players)
VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, {
    Animation = Anims["SkillName"],
    Speed = seq.Speed,
})

VFXService:StartEffect(Players:GetPlayers(), "Sound", RootPart, Sounds["SkillName"])
VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", {
    UUID = self.SomeUUID,
    Particle = Models["ParticleName"],
    Origin = character.RootPart,
})
VFXService:StartEffect(Players:GetPlayers(), "Highlight", character.instance, {
    FillColor = Color3.fromRGB(255, 0, 0),
    OutlineColor = Color3.fromRGB(255, 0, 0),
    FillTransparency = 0.5,
    OutlineTransparency = 0,
    Lifetime = 1,
    Tween = true,
})

-- Stop an effect
VFXService:StopEffect(Players:GetPlayers(), "Animation", character.instance, {
    Animation = Anims["SkillName"].Animation,
})
VFXService:StopEffect(Players:GetPlayers(), "EmitParticle", self.SomeUUID)
```

---

## SkillCharacters Tags (Arbitrary Categorization)

`SkillCharacters` is an array of strings that describe the skill's combat role. There is **no fixed enum** — tags are freeform. Examples from the codebase:

```luau
SkillCharacters = { "Hit" }                        -- Deals damage
SkillCharacters = { "Defense" }                     -- Defensive move
SkillCharacters = { "Escape", "Defense", "ComboStarter" }
SkillCharacters = { "Hit", "ComboExtender", "Blockable" }
SkillCharacters = { "Grab", "ComboEnder", "Hit", "Ragdoll", "IgnoreBlock" }
SkillCharacters = { "Ragdoll", "PerfectBlockable", "Hit", "ComboEnder", "Armored", "BlockBreaker" }
```

---

## Combo System (Punch pattern)

Punch.luau demonstrates the combo system:

```luau
-- SkillData fields:
ComboCooldown = 1.5,     -- Cooldown after max combo
ComboResetTime = 1.5,    -- Time before combo resets
MaxCombo = 4,            -- Number of hits in combo

-- In Activate:
self.PunchCount += 1
if self.PunchCount > self.Data.MaxCombo then
    self.PunchCount = 1
    self:SetCooldown(self.Data.ComboCooldown)
elseif self.Data.ComboResetTime then
    local oldCount = self.PunchCount
    task.delay(self.Data.ComboResetTime, function()
        if oldCount == self.PunchCount then
            self.PunchCount = 1
        end
    end)
end
```

Animation naming follows: `Punch1`, `Punch2`, `Punch3`, `Punch4`.

---

## Dash Pattern

```luau
-- SkillData fields:
DashProperties = {
    Speed = 50,
    Time = 0.25,
}

-- In onInit, uses direction detection helper:
local function GetDashDirection(Normal)
    -- returns "Forward", "Back", "Left", or "Right"
end

-- Animation naming: DashForward, DashBack, DashLeft, DashRight
```

---

## Grab Pattern (Two Sequences)

Grab has a complex multi-sequence flow:

1. **`Sequence`** — The approach/grab attempt. Uses hitbox to find target. On hit, starts `GrabSequence`.
2. **`GrabSequence`** — The throw animation. Binds target to attacker, plays throw anim, applies throw damage.

```luau
-- SkillData fields:
OnGrab = function(self: SkillData, target: Character) end  -- Called on grab connect
OnThrow = function(self: SkillData, target: Character) end -- Called on throw

AttackInfo = {
    Hitbox = { Size, Offset, SortByDistance = true },
    Block = { PerfectBlockable = false, BlockCancel = true },
}

Throw = {
    Damage = 10,
    Block = { PerfectBlockable = false, BlockCancel = true },
    Knockback = { Duration, Velocity, Speed, RelativePart, FindCrashObject },
    Ragdoll = { Duration },
    Stun = { Priority, Duration },
    Angular = { Velocity, Duration },
}
```

Grab stats come from spec skin config (`self.Spec.Data.Assets.Stats.Grab`):
```luau
self.GrabData = {
    Prefix = "StandOff",
    Offset = self.Spec.Data.Assets.Stats.Grab["AnimationOffset"] or CFrame.new(0, 0, -4) * CFrame.Angles(0, 180, 0),
    StartHitFrame = self.Spec.Data.Assets.Stats.Grab["StartHitFrame"] or 30,
    EndHitFrame = self.Spec.Data.Assets.Stats.Grab["EndHitFrame"] or 40,
    FinalFrame = self.Spec.Data.Assets.Stats.Grab["FinalFrame"] or 30,
}
```

---

## Barrage Pattern (Multi-Phase Attack)

Three distinct attack phases, each with its own AttackInfo:

```luau
PreBarrageInfo = { Hitbox, Damage, Block, Stun }
BarrageInfo = { Hitbox, Damage, Block, Stun, Knockback }  -- Looping section
PostBarrageInfo = { Hitbox, Damage, Block, Stun, Knockback }
```

The sequence loops on the barrage frames (frame 45-190), emitting hits every N frames:
```luau
{45, function(seq, frame)
    if frame % 4 ~= 0 then return end  -- Hit every 4 frames
    -- Hitbox + Attack
end, 190}  -- loopEndFrame
```

---

## Registration

### Step 1 — Create the skill module file

```
src/server/skills/YourSkill.luau          -- shared skills (all specs can use)
src/server/skills/CharName/YourSkill.luau -- character-unique skills
```

### Step 2 — Add to spec

In `src/server/specs/CharName.luau`:

```luau
local Spec = {
    Skills = {
        ["YourSkill"] = "~/skills/YourSkill",              -- shared skill
        ["YourSkill"] = "@Specs/CharName/YourSkill",        -- unique skill
    },
}
```

### Step 3 — Add binds (optional)

In `src/shared/configs/Specs.luau` under the spec's `Binds`:

```luau
["YourSkill"] = Enum.KeyCode.R,
```

---

## Quick Reference — What to Copy From

| If you want... | Look at... |
|---|---|
| Simple toggle skill | `Run.luau` |
| Single hit with sequence | `ArcSpearStrike.luau` |
| Combo system | `Punch.luau` |
| Defensive/block skill | `Block.luau` |
| Mobility skill | `Dash.luau` |
| Multi-phase attack | `Barrage.luau` |
| Grab/throw skill | `Grab.luau` |
| Ground-pound/foot | `Footrest.luau` |
| Launch/uppercut | `Uppercut.luau` |
