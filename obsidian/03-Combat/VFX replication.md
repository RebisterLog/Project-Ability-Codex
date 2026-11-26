# VFX replication

`VFXService` starts and stops effects on a chosen player list. Effects are implemented under `src/shared/effects/` and are started by server code during a sequence or an attack. Every method takes **exactly three arguments**:

```luau
VFXService:StartEffect(players, name, data)
VFXService:StopEffect(players, name, data)
VFXService:StartEffectExcept(players, name, data) -- everyone NOT in players
VFXService:StopEffectExcept(players, name, data)
```

`players` is a list of `Player` objects or character `Model`s; `data` is the protocol table declared by the effect module. There is no positional `RootPart`, instance or animation argument — older four-argument examples are obsolete.

```luau
-- Animation: START takes the clip TABLE; STOP takes the raw clip.Animation
VFXService:StartEffect(Players:GetPlayers(), "Animation", {
    Character = self.Character.instance, Animation = self:GetAsset("Animations/NAME"),
    Speed = seq.Speed,
})
VFXService:StopEffect(Players:GetPlayers(), "Animation", {
    Character = self.Character.instance, Animation = clip.Animation, FadeTime = 0.1,
})

VFXService:StartEffect(Players:GetPlayers(), "Sound", {
    Origin = self.Character.RootPart, Sound = self:GetAsset("Sounds/NAME"), Volume = 1,
})
VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", {
    UUID = self.ParticleUUID, Particle = self:GetAsset("Models/ParticleName"),
    Origin = self.Character.RootPart,
})
VFXService:StopEffect(Players:GetPlayers(), "EmitParticle", { UUID = self.ParticleUUID })
VFXService:StartEffect(Players:GetPlayers(), "Highlight", {
    Character = target.instance, FillColor = Color3.new(1, 0, 0),
    Lifetime = 1, Tween = true,
})
```

| Kind | `data` payload |
|---|---|
| `Animation` | `Character` (Model), `Animation` (clip table on start / raw instance on stop), optional `Speed`, `Type`, `FadeTime`. |
| `Sound` | `Origin` (CFrame or Instance), `Sound`, `Volume`, `MaxDistance`, `MinDistance`. |
| `EmitParticle` | `UUID` (kept for stopping), `Particle`, `Origin`, optional `Offset`, `UseForge`. |
| `Highlight` | `Character` / `Adornee` / `UUID`, colors and transparencies, `Lifetime`, `Tween`. |
| `Hitbox`, `Ragdoll`, `Barrage`, `CameraShake`, ... | used by combat hooks and debug views; read the effect module for its protocol. |
## Rules

1. Every started effect must be stopped: register the stop once at frame 0 in `seq.Cleaner` (or in the skill's `self.Cleaner` for skill-lifetime effects) so it runs on both natural end and interruption.
2. Assets come from the spec skin through `self:GetAsset(...)`; see [[Spec and SubSpec]].
3. The player list controls who sees the effect; the server decides that list. Use the `Except` variants to hide an effect from a set of players (for example the caster).
4. Stopping an `Animation` effect uses the raw `clip.Animation`, while starting uses the clip table — do not pass the same value to both. See [[Skill contract and lifecycle]].

Related: [[Sequencer]], [[Combat pipeline]], [[Attack hooks]].
