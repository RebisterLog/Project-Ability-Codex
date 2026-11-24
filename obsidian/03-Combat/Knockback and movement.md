# Knockback and movement

Knockback configuration lives in `src/shared/combat/Knockback.luau` and is embedded in `AttackInfo.Knockback`.

| Field | Meaning |
|---|---|
| `Preset` | Named shortcut for a combination of `Push`, `Lift` and `Hold` (for example `"Launch"`). |
| `Direction.Mode` | `AwayFromAttacker`, `TowardsAttacker`, `FromPoint`, `Custom`. |
| `Direction.Point` / `Vector` / `Add` | Inputs for non-relative modes and extra offset. |
| `Push` | Horizontal studs/second along `Direction`. |
| `Lift` | Vertical studs/second. |
| `Hold` | Mover lifetime in seconds — **not** damping. |
| `Stiffness` | Spring stiffness of the mover. |
| `MaxForce` | `"Auto"` (default) unlocks the Y axis only when `Lift` is non-zero. |

## Movement parameters

`MaxWalkSpeed`, `MinWalkSpeed` and `MaxJumpPower` are layered [[Character parameters]]. Skills typically lower `MaxWalkSpeed` during a sequence and release it through `seq.Cleaner`.

## Angular motion

`AttackInfo.Angular` carries `Velocity`, `Speed`, `Duration` and `MaxTorque`; the `Angular` hook applies it alongside knockback.

## Practical rule

Tune `Push`/`Lift`/`Hold` first, then consider a `Preset` for reuse. Changing only the client-side animation will not change where the character actually moves.

Related: [[AttackInfo and AttackData]], [[Attack hooks]], [[Character parameters]].
