# Bot combat AI

Bot behaviour is built around a **single action slot**: on each tick a bot chooses one action (attack, guard, reposition, wait) rather than running parallel state machines.

## Layers

1. **Sensors / inputs** — current target, distance, incoming hit, cooldowns.
2. **Conditions** — a bitmask describing the current situation.
3. **Roles** — derived from tags on the bot configuration, not from a rigid role enum. Roles change which actions score well.
4. **Scoring** — each candidate action is scored against role, conditions and posture.
5. **Execution** — the winning action writes into the single action slot.

## Roles and tags

Roles come from tags. A `"Guard"` role favours defensive actions; a counter role favours punishing a released guard. The same tag set can produce different behaviour depending on the current posture.

## Posture

Posture replaces a large state machine: it is a small set of stances (for example neutral, guarding, recovering) that biases scoring. Posture changes are cheap and let bots react without a full transition graph.

## Defense: two entry points

- **Immediate:** an incoming hit triggers a defensive reaction right away (block, dodge, armor).
- **On tick:** guard release is evaluated during the regular tick, so the bot can decide to counter or re-guard.

## Attack

Attacks are combos selected by scoring: range, target state, cooldowns and role weights decide which combo to start and when to extend or end it.

## Navigation and pathfinding

The navigator uses a short line of sight check that distinguishes a **clear** result (cached for 2 seconds) from a **blocked** result (cached for 0.5 seconds). Any raycast hit on something other than the target counts as an obstacle; the old 5-stud tolerance was removed. A ray with a vertical angle above `MaxDirectPitch` (12 degrees by default) is treated as blocked, so bots do not try to walk straight up ledges.

The attack layer is skipped entirely while the navigator is in `Pathfinding` or `FollowingPath`; the defense layer (guard, immediate dodge) still runs. This prevents casting skills at a target the bot cannot see.

While a path is being computed the bot keeps a simple forward approach without movement styling. Once a path exists, `FollowingPath` moves strictly toward waypoints, but each reached waypoint skips **half of the remaining points** instead of advancing by one — clamped to the last point, so `Arrived` can only start from a waypoint the bot actually reached. It returns to `Direct` only after two consecutive fresh clear line-of-sight checks. When the path is exhausted, the bot enters `Arrived`: it stops moving and attacks from there instead of pushing closer to `ReachDistance`. However, every 0.25 s it re-checks visibility: with no line of sight it keeps closing and re-paths (2 s cooldown), and if the target is more than 9 studs away it resumes `Direct` or `Pathfinding`. Paths expire after 5 seconds and are recalculated when the target moves far enough or the bot gets stuck. A bot that has a target but neither attacks nor closes for 4 s is restarted by the bot-level stall watchdog.

## Facing

`RotateToTarget` is the single source of rotation for bots. `AlignOrientation` follows the target only while the movement style is `direct` and the body is not owned by path following. Sway/impulse styles (`strafe`, `zigzag`, `puma`, `lunge`, `sidestep`, `flank`, `orbit`) deliberately move at an angle to the target, so they let `Humanoid.AutoRotate` follow the movement direction instead of fighting the constraint; exact facing is enforced at cast time. Rotation is disabled while following a path, during grabs (`DisableRotation`) and while ragdolled. `FaceTarget` re-applies the target yaw at 20 Hz whenever the bot's current `LookVector` drifts more than about 2° from the direction to the target — this includes moving toward a stationary target. `Bot.ActivateSkill` calls `FaceTargetNow` before every cast so a skill's hitbox, which reads `LookVector` in the same tick, sees the correct facing. That same-tick snap pivots the whole rig with a rotation-only goal and preserves `AssemblyLinearVelocity`/`AssemblyAngularVelocity`; writing `rootPart.CFrame` directly used to drop the assembly momentum and made the bot stutter on every cast.

## Dash is a dodge, not a filler

Skills tagged `Escape` are excluded from attack scoring while navigation owns the body (`Pathfinding`, `FollowingPath`, `HoldingDistance`). Outside that, they are allowed in two cases: a real dodge intent (`TARGET_ATTACKING` or `OWN_THREATENED`), or a deliberate combo opener inside its configured distance band (`Distance` and `PreferredDistance` in the bot config). That keeps Dash as an engage tool without turning it into a random gap filler. Emergency dodges still come from the defense layer on an incoming hit and work during pathfinding.

## Stuck recovery

A bot is treated as stuck only after 1.5 seconds with less than 0.75 studs of displacement, with `WalkSpeed` of at least 5 and no active dash mover (`DashLinearVelocity`). Skill locks (`Dash`, `Block`, attacks) hold `WalkSpeed` near zero for their whole sequence, so they are explicitly **not** a stall: counting them used to teleport the rig mid-dash and freeze the bot in place. The same pure rule lives in `NavigationController/StuckRules.luau` and is covered by `lune run tools/tests/StuckRules.test.luau`. On a real stall, recovery first invalidates line of sight, drops the path and forces recalculation; on a repeat it pivots onto the **midpoint of the remaining waypoints** (with a downward ground probe) while keeping the assembly velocity, with a 4-second cooldown and at most two teleports per path. If the bot is still stuck after that teleport, the next stuck check moves it to a point 4 studs from the target instead, with a 6-second cooldown. If no path is produced within 5 seconds, the same near-target move applies with a 10-second cooldown, so a bot wedged in geometry can still reach the player. Path budgets and recalculation intervals now use the same `GetServerTimeNow()` clock as the state machine.

## A tick in full

```
read sensors -> build condition bitmask -> resolve role from tags
-> update posture -> score actions -> write single action slot
-> run action (skills, movement) -> cleanup
```

## Tuning and gaps

Tune weights and thresholds in bot configuration; use [[Character parameters]] for temporary state. Known gaps: limited long-term memory, simple target selection, and defensive reactions that can overlap during respawns. See [[Known gaps and roadmap]].

Related: [[Combat pipeline]], [[Services and dependencies]], [[Character parameters]].
