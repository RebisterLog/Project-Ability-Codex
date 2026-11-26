# AttackInfo and AttackData

`AttackInfo` describes an attack before it is resolved. `AttackData` is the result returned by `CombatService:Attack(...)` as a Promise.

## AttackInfo fields (all optional)

| Field | Contents |
|---|---|
| `Priority` | Ordering/priority of the attack. |
| `Hitbox` | Skill-private convention for the `Info` passed to [[Hitbox and targeting]]; not part of the `AttackInfo` type. |
| `Damage` | Damage amount. |
| `Block` | All five flags are **required booleans**: `Blockable`, `PerfectBlockable`, `BlockBreak`, `BlockCancel`, `BlockIgnore`. See below. |
| `Stun` | `Duration`, `Priority` (`Enums.Stun`). |
| `Bleed`, `Burn` | Damage-over-time parameters. |
| `Knockback` | `Preset`, `Direction { Mode, Point/Vector, Add }`, `Push`, `Lift`, `Hold`, `Stiffness`, `MaxForce`. See [[Knockback and movement]]. |
| `Ragdoll` | `Duration`. |
| `Angular` | `Velocity`, `Speed`, `Duration`, `MaxTorque`. |
| `HitEffects`, `HitSounds`, `HitAnimations` | Replication payloads for a landed hit. |

`BlockIgnore` is dominant (bypasses block entirely); `BlockBreak` is **independent** of `Blockable`. One exception matters for guard-breakers: a perfect block against `PerfectBlockable = true` resolves first (`Block.luau:89-96`), producing `PerfectBlocked`/`Absorbed` and preventing `BlockBreak` entirely — so a finisher meant to break a held guard must set `PerfectBlockable = false`. A blocked hit yields `State.Absorbed`, which strips Damage, Ragdoll, Restand, Stun, Bleed, HitEffects, Knockback and Angular from the applied hit. `CombatService:Attack` clones and deep-freezes `Info`; the original is kept as `AttackData.OriginalInfo`.

To make a perfect block parry but let an ordinary block pass through, use `Blockable = false, PerfectBlockable = true, BlockIgnore = false`. `BlockResolver` then absorbs only the perfect branch; a held ordinary block sets neither `Blocked` nor `Absorbed`, so the hit lands. Do not reimplement this by reading `victim.Block.PerfectBlockTime`/`os.clock()` in a skill — the resolver already uses the authoritative victim state.

`HitEffects` is an **array of tables** (`{ { Particle = ..., Sound = ... } }`), not a Folder. String values other than `"Default"` are resolved through `skill:TryGetAsset(...)`, so an attack using skin-relative keys must pass `Skill = self` to `CombatService:Attack`.

**Knockback**: presets are `"Tap"`, `"Shove"`, `"Slam"` and `"Launch"`. `Direction.Mode` accepts `"AwayFromAttacker"`, `"TowardsAttacker"`, `"FromPoint"`, `"Custom"` and `"ToFront"`; `Direction.Add` accepts `ToFront`/`Custom` offsets. `Stiffness` defaults to `math.huge`; `MaxForce` defaults to `"Auto"` (unlock Y only when `Lift ~= 0`) and may be a `Vector3`. `Hold` is the mover lifetime, not damping.

## Enum values

```
IFrames: Ragdoll=10, Dodge=15, Grab=50, True=10000
Stun:    None=0, Light=10, Medium=20, Heavy=30
```

## AttackData.State

| Flag | Meaning |
|---|---|
| `Success` | Hit registered; not a miss, i-frame or dead target. |
| `Continue` | Follow-up / combo is allowed. |
| `Blocking` | Target was holding block. |
| `Blocked` | Hit landed on block. |
| `BlockBroken` | Block was broken by this hit. |
| `BlockCanceled` | Block was canceled entirely. |
| `PerfectBlocking` | Target was in the perfect-block window. |
| `PerfectBlocked` | Attacker was punished by the perfect block. |
| `BlockIgnored` | Attack bypassed block (for example a grab). |
| `Absorbed` | Hit was absorbed by block; damage and most other effects are stripped before application. |
| `IFrames` | Target's i-frame level (number). |
| `Armored` | Target had super armor. |

At runtime `State` may also carry `Ragdolled` and `Absorbed` in addition to the declared flags above.

`AttackData` also carries `OriginalInfo`, `DamageDealt` and `NoDeathDeferred`.

## Example outcomes

```
normal hit:   Success, Continue
normal block: Success, Continue, Blocking, Blocked, Absorbed
block break:  Success, Continue, Blocking, Blocked, BlockBroken
perfect block: Success, Blocking, Blocked, PerfectBlocking, PerfectBlocked, no Continue
block cancel: Success, Continue, Blocking, BlockCanceled
```

## Related

[[Attack hooks]], [[Hitbox and targeting]], [[Character parameters]], [[Knockback and movement]].
