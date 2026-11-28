# Character parameters

Parameters are layered, temporary modifiers on a character component. Multiple sources can add the same parameter; the effective value is resolved **by parser, not by "newest wins"**, and each layer is removed when its owner is cleaned up.

```luau
const mod = character:AddParameter("MaxWalkSpeed", 3) -- { Value, Cleaner, Destroy }
const current = character:GetParameter("MaxWalkSpeed")
mod:Destroy() -- release this layer
```

Layering: `LowestParser` for `MaxWalkSpeed`/`MaxJumpPower`, `HighestParser` for `MinWalkSpeed`/`IFrames`, a priority parser for `Stun`, `MultParser` for multipliers, `ORParser` for booleans, and `LastParser` for `CastingSkill`.

| Parameter | Effect |
|---|---|
| `MaxWalkSpeed` | Movement speed cap (lowest wins). |
| `MinWalkSpeed` | Minimum movement speed (used by `Run`; highest wins). |
| `MaxJumpPower` | Jump power cap. |
| `IFrames` | Invincibility level (`Enums.IFrames`). |
| `Stun` | `{ Duration, Priority }` (`Enums.Stun`). |
| `Armor` | Super armor; see [[AttackInfo and AttackData]]. |
| `Timescale` | Animation/speed multiplier; used by `seq.Speed` (clamped 0..10) and watched by active sequences, so a mid-cast change retunes them. |
| `CastingSkill` | Active cast lock (last wins). |
| `CooldownMultiplier`, `DamageMultiplier`, `DamageReceivalMultiplier`, `HealMultiplier` | Multiplicative modifiers. |
| `Ragdoll`, `Restrain`, `NoCollision`, `NoRotate` | State overrides. |
| `Bleeding`, `Burning`, `GodMode`, `Restand`, `NoSkillCast`, `NoDeath`, `DamageHold`, `HamonCharge` | Other flags/counters. |

Other helpers: `SetParameterValue`, `RefreshParameter`, `WatchParameter`. Use `Enums.CastSpeed.Medium` (not a literal) for cast-time speed caps.

## Ownership

Add parameters in `onInit` or in a frame callback, then register the returned object with `self.Cleaner` or `seq.Cleaner` (both `Crane.Buttler`s). On [[Sequencer]] interruption, the cleaner releases every layer, so movement returns to its previous state automatically.

Related: [[Skill contract and lifecycle]], [[Knockback and movement]], [[Bot combat AI]].
