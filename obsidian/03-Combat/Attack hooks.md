# Attack hooks

Every attack passes through a three-phase hook pipeline before its result is final.

```luau
self.AttackHook = Hook.new("Attack", { "Precast", "Cast", "Postcast" })
self.AttackHook:Hook("Precast", "MyHook", priority, function(Data)
    return true -- false / nil aborts the pipeline
end)
```

| Phase | Purpose |
|---|---|
| `Precast` | Before effects: validation and `Attacked` signal. |
| `Cast` | Apply hit effects (damage, stun, knockback, etc.). |
| `Postcast` | Finalise and return the result. |

A hook receives `AttackData` and **must return `true`** to continue. Lower-priority hooks run later; priority ordering matters when one hook changes state another hook reads.

## Hooks present in the codebase

`Angular`, `Armor`, `Bleed`, `Block`, `Burn`, `Damage`, `HitFeedback`, `IFrames`, `Knockback`, `NPCOwnership`, `Ragdoll`, `Restand`, `Stun`. They live under `src/server/services/CombatService/Hooks/` and are auto-loaded.

## Signals

- `Casted` — fired by `CombatService:Hitbox` when a skill is supplied.
- `Attacked` — fired during the attack pipeline; used by block and feedback logic.
- `Interrupted` — skills with `Interrupt` subscribe here.

Related: [[Create a hook]], [[AttackInfo and AttackData]], [[Combat pipeline]], [[Bot combat AI]].
