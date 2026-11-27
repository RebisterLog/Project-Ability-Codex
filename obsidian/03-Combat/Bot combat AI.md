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

`RotateToTarget` is the single source of rotation for bots. `AlignOrientation` follows the target whenever the body is not owned by path following — including the `orbit` and `strafe` styles used in Defend, so backing off sideways must not turn the bot away from its target. Rotation is disabled while following a path, during grabs (`DisableRotation`) and while ragdolled. `FaceTarget` re-applies the target yaw at 20 Hz whenever the bot's current `LookVector` drifts more than about 2° from the direction to the target — this includes moving toward a stationary target. `Bot.ActivateSkill` calls `FaceTargetNow` before every cast to force the constraint's yaw update; it never writes the rig's CFrame, so an attack-triggered cast cannot snap the character to a new spot.

## Dash is a dodge, not a filler

Skills tagged `Escape` are excluded from attack scoring while navigation owns the body (`Pathfinding`, `FollowingPath`, `HoldingDistance`). Outside that, they are allowed in two cases: a real dodge intent (`TARGET_ATTACKING` or `OWN_THREATENED`), or a deliberate combo opener inside its configured distance band (`Distance` and `PreferredDistance` in the bot config). That keeps Dash as an engage tool without turning it into a random gap filler. Emergency dodges still come from the defense layer on an incoming hit and work during pathfinding.

## Stuck recovery

A bot is treated as stuck only after 1.5 seconds with less than 0.75 studs of displacement, with `WalkSpeed` of at least 5 and no active dash mover (`DashLinearVelocity`). Skill locks (`Dash`, `Block`, stun) hold `WalkSpeed` near zero for their whole sequence, so they are explicitly **not** a stall: counting them made the bot repath and jump in the middle of a fight. The pure rule lives in `NavigationController/StuckRules.luau`. On a real stall, recovery only invalidates line of sight, drops the path and forces recalculation; a repeated stall adds a jump. There are no teleports — teleporting the rig mid-fight made bots visibly snap when the player attacked them. Path budgets and recalculation intervals use the same `GetServerTimeNow()` clock as the state machine.

## A tick in full

```
read sensors -> build condition bitmask -> resolve role from tags
-> update posture -> score actions -> write single action slot
-> run action (skills, movement) -> cleanup
```

## Tuning and gaps

Tune weights and thresholds in bot configuration; use [[Character parameters]] for temporary state. Known gaps: limited long-term memory, simple target selection, and defensive reactions that can overlap during respawns. See [[Known gaps and roadmap]].

Related: [[Combat pipeline]], [[Services and dependencies]], [[Character parameters]].
