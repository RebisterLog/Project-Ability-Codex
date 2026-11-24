# Create a hook

Hooks alter every attack through the `Precast` → `Cast` → `Postcast` pipeline. They live under `src/server/services/CombatService/Hooks/` and are auto-loaded.

## Checklist

1. Create `src/server/services/CombatService/Hooks/<Name>.luau`.
2. Decide the phase: `Precast` for validation/state, `Cast` for effects, `Postcast` for finalisation.
3. Register with the desired priority:
   ```luau
   hook:Hook("Precast", "MyHook", priority, function(Data)
       -- read/modify AttackData.State
       return true -- false / nil aborts the pipeline
   end)
   ```
4. Always return `true` when processing should continue.
5. Consider ordering: a hook that changes state must run before hooks that read it.
6. Verify formatting and inspect dependents before committing. See [[Formatting and inspection]].

## Existing hooks

`Angular`, `Armor`, `Bleed`, `Block`, `Burn`, `Damage`, `HitFeedback`, `IFrames`, `Knockback`, `NPCOwnership`, `Ragdoll`, `Restand`, `Stun`.

## Related

[[Attack hooks]], [[AttackInfo and AttackData]], [[Combat pipeline]], [[Create a service or component]].
