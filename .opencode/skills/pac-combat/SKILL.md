---
name: pac-combat
description: PAC combat architecture: Skill lifecycle, Sequencer, AttackHook/AttackInfo/AttackData, parameters, VFXService.
---

# PAC Combat

## Skill lifecycle flow
Client input → packet `StartSkill` → `SkillService` validates (cooldown, stun, ragdoll, alive) → `spec:ActivateSkill` → `Skill:Activate` → sequence plays → hitbox checks on frames → `CombatService:Attack` → VFX replicated → proxy updates client.

## Sequencer (frame-based)
```luau
self.Sequence = CombatService.CreateSequence(character, {
    Validate = function() return true end,
    Frames = {
        {0, function(seq)
            seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 3))
            VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, { Animation = Anims.X, Speed = seq.Speed })
            seq.Cleaner:Add(function() VFXService:StopEffect(...) end)
        end},
        {15, function(seq) /* hitbox */ end, 20}, -- loops 15-20
        {45}, -- end
    }
})
self.Sequence:Play(); self.Sequence:Await(); self.Sequence:Stop()
self.Sequence:AdjustSpeed(mult); self.Sequence.CurrentFrame
```
- Cleaner inside seq: `Add`, `Set(key, obj)`, `Remove(key)`.

## AttackHook
```luau
self.AttackHook = Hook.new("Attack", {"Precast","Cast","Postcast"})
self.AttackHook:Hook("Precast", "MyHook", priority, function(Data) return true end)
```
Callback returns true to continue, false/nil to abort.

## AttackInfo fields (all optional)
- Priority, Damage
- Block { Blockable, PerfectBlockable, BlockBreak, BlockCancel, BlockIgnore }
- Stun { Duration, Priority (Enums.Stun.*) }
- Knockback { RelativePart/RelativeTowards, ToFront, Origin, Speed, Duration, Velocity, MaxForce, FindCrashObject }
- Angular { Velocity, Speed, Duration, MaxTorque }
- Ragdoll { Duration }

Enums: IFrames Ragdoll=10 Dodge=15 Grab=50 True=10000; Stun None=0 Light=10 Medium=20 Heavy=30.

## AttackData.State
Success, Continue, Blocking, Blocked, BlockBroken, BlockCanceled, PerfectBlocking, PerfectBlocked, BlockIgnored, IFrames, Armored.

## Hitbox
```luau
CombatService:Hitbox({
    Skill = self,          -- optional, fires Casted signal
    Caster = character,    -- required
    Info = { Size,         -- Vector3 (box) or number (sphere radius)
            Offset,       -- CFrame offset from RootPart
            Origin,       -- override
            SortByDistance, CanQueryCaster, Parameters, Debug }
})
```

## Character parameters (layered)
```luau
local m = character:AddParameter("MaxWalkSpeed", 3)  -- .Destroy() removes
character:GetParameter("MaxWalkSpeed")
-- Common: MaxWalkSpeed, MaxJumpPower, IFrames, Stun, Armor, Timescale, Ragdoll, Restrain, NoCollision, MinWalkSpeed
```

## VFXService
```luau
VFXService:StartEffect(Players:GetPlayers(), "Animation", instance, { Animation=..., Speed=... })
VFXService:StartEffect(players, "Sound", root, sound)
VFXService:StartEffect(players, "EmitParticle", { UUID=..., Particle=..., Origin=... })
VFXService:StartEffect(players, "Highlight", instance, { FillColor=..., Lifetime=..., Tween=true })
-- StopEffect(players, kind, target/uuid, payload)
```

## Cleanup
Janitor on service/skill; every spawned resource tracked; vfx stopped on interrupt; params released via seq.Cleaner/Destroy.