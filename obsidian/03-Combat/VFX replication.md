# VFX replication

`VFXService` starts and stops effects on a chosen player list. Effects are implemented under `src/shared/effects/` and are started by server code during a sequence or an attack.

```luau
VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, {
    Animation = anim, Speed = seq.Speed,
})
VFXService:StartEffect(Players:GetPlayers(), "Sound", rootPart, sound)
VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", {
    UUID = self.UUID, Particle = particle, Origin = rootPart,
})
VFXService:StartEffect(Players:GetPlayers(), "Highlight", instance, {
    FillColor = Color3.new(1, 0, 0), Lifetime = 1, Tween = true,
})
VFXService:StopEffect(Players:GetPlayers(), "Animation", character.instance, { Animation = anim })
```

| Kind | Target argument |
|---|---|
| `Animation` | character instance + animation payload. |
| `Sound` | origin instance + sound payload. |
| `EmitParticle` | payload with `UUID`, `Particle`, `Origin`. |
| `Highlight` | instance + highlight payload. |
| `Hitbox`, `Ragdoll` | used by combat hooks and debug views. |

## Rules

1. Every started effect must be stopped: register the stop in `seq.Cleaner` or the skill's `Janitor`.
2. Assets come from the spec skin through `self:GetAsset(...)`; see [[Spec and SubSpec]].
3. The player list controls who sees the effect; the server decides that list.
4. Interrupted skills stop their effects in `Interrupt`. See [[Skill contract and lifecycle]].

Related: [[Sequencer]], [[Combat pipeline]], [[Attack hooks]].
