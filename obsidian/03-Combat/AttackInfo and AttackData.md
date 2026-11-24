# AttackInfo and AttackData

`AttackInfo` describes an attack before it is resolved. `AttackData` is the result returned by `CombatService:Attack(...)` as a Promise.

## AttackInfo fields (all optional)

| Field | Contents |
|---|---|
| `Priority` | Ordering/priority of the attack. |
| `Damage` | Damage amount. |
| `Block` | `Blockable`, `PerfectBlockable`, `BlockBreak`, `BlockCancel`, `BlockIgnore`. |
| `Stun` | `Duration`, `Priority` (`Enums.Stun`). |
| `Knockback` | `Preset`, `Direction { Mode, Point/Vector, Add }`, `Push`, `Lift`, `Hold`, `Stiffness`, `MaxForce`. See [[Knockback and movement]]. |
| `Angular` | `Velocity`, `Speed`, `Duration`, `MaxTorque`. |
| `Ragdoll` | `Duration`. |

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
| `IFrames` | Target's i-frame level (number). |
| `Armored` | Target had super armor. |

## Example outcomes

```
normal hit:   Success, Continue
normal block: Success, Continue, Blocking, Blocked
block break:  Success, Continue, Blocking, Blocked, BlockBroken
perfect block: Success, Blocking, Blocked, PerfectBlocking, PerfectBlocked, no Continue
block cancel: Success, Continue, Blocking, BlockCanceled
```

## Related

[[Attack hooks]], [[Hitbox and targeting]], [[Character parameters]], [[Knockback and movement]].
