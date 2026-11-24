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
| `MovementCorrection` | Move the query origin to the caster's latency-compensated client pose (bounded to 3 studs, horizontal only); falls back to a 2-stud velocity heuristic for bots/invalid samples. Ignored when `Origin` is explicit. See [[Lag compensation]]. |
| `Debug` | Visualise the query through VFX. |

## Common pattern

Loop frames call the hitbox, skip targets already in `self.AlreadyHit`, call `CombatService:Attack`, and add the target to `AlreadyHit` only when `Data.State.Success` is true. This prevents multiple hits per target during a looping sequence.

Client-side `TargetLockService` handles target selection/presentation only; it does not decide hits. See [[Runtime boundaries]].

Related: [[Sequencer]], [[AttackInfo and AttackData]], [[Character parameters]], [[Lag compensation]].
