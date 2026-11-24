# Character parameters

Parameters are layered, temporary modifiers on a character component. Multiple sources can add the same parameter; the newest layer wins and is removed when its owner is cleaned up.

```luau
local mod = character:AddParameter("MaxWalkSpeed", 3)
local current = character:GetParameter("MaxWalkSpeed")
mod:Destroy() -- release this layer
```

| Parameter | Effect |
|---|---|
| `MaxWalkSpeed` | Movement speed cap. |
| `MinWalkSpeed` | Minimum movement speed (used by `Run`). |
| `MaxJumpPower` | Jump power cap. |
| `IFrames` | Invincibility level (`Enums.IFrames`). |
| `Stun` | `{ Duration, Priority }` (`Enums.Stun`). |
| `Armor` | Super armor; see [[AttackInfo and AttackData]]. |
| `Timescale` | Animation/speed multiplier; used by `seq.Speed`. |
| `Ragdoll` | Force ragdoll state. |
| `Restrain` | Disable movement. |
| `NoCollision` | Disable character collision. |

## Ownership

Add parameters in `onInit` or in a frame callback, then register the returned object with `self.Janitor` or `seq.Cleaner`. On [[Sequencer]] interruption, the cleaner releases every layer, so movement returns to its previous state automatically.

Related: [[Skill contract and lifecycle]], [[Knockback and movement]], [[Bot combat AI]].
