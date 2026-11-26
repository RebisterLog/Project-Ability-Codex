# Hitbox and targeting

`CombatService:Hitbox` is a server-side spatial query returning candidate `Character` components.

```luau
local targets = CombatService:Hitbox({
    Skill = self,             -- optional; fires Casted
    Caster = character,       -- required
    Info = {
        Size = Vector3.new(7, 7, 7), -- Vector3 => box, number => sphere radius
        Offset = CFrame.new(0, 0, -3),
        Origin = CFrame.new(),  -- optional override
        SortByDistance = true,
        CanQueryCaster = false,
        Parameters = OverlapParams.new(),
        Debug = false,
        MovementCorrection = true, -- bounded lag compensation for melee
    },
})
```

| Field | Behaviour |
|---|---|
| `Size` | `Vector3` uses `GetPartBoundsInBox`; `number` uses `GetPartBoundsInRadius`. |
| `Offset` | Applied from the caster's `RootPart`. |
| `Origin` | Replaces the default origin when supplied. |
| `SortByDistance` | Nearest targets first. |
| `CanQueryCaster` | Allow the caster to be returned. |
| `Parameters` | Custom `OverlapParams`. |
| `MovementCorrection` | Uses `ClientStateService:GetMetadata(Caster).Predicted` (the client-rendered pose extrapolated for latency) when available; otherwise falls back to a velocity heuristic clamped by `MOVEMENT_CORRECTION_LIMIT = 2`. Ignored when `Origin` is explicitly set. `Punch.luau` uses it. See [[Lag compensation]]. |
| `Debug` | Visualise the query through VFX. |

## Common pattern

Repeated frames call the hitbox, skip targets already in `self.AlreadyHit`, call `CombatService:Attack`, and add the target to `AlreadyHit` only when `Data.State.Success` is true. This prevents multiple hits per target during a repeated-hit sequence (see [[Sequencer]] for `Interval`/`Offset`).

Client-side `TargetLockService` handles target selection/presentation only; it does not decide hits. See [[Runtime boundaries]].

Related: [[Sequencer]], [[AttackInfo and AttackData]], [[Character parameters]], [[Lag compensation]].
