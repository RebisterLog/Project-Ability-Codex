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

The navigator uses a short line of sight check that distinguishes a **clear** result (cached for 2 seconds) from a **blocked** result (cached for 0.5 seconds). Any raycast hit on something other than the target counts as an obstacle; the old 5-stud tolerance was removed. A ray with a vertical angle above `MaxDirectPitch` (40 degrees by default) is treated as blocked, so bots do not try to walk straight up ledges.

Entering `Pathfinding` does not push the bot into the obstacle: while a path is being computed the bot performs a light sidestep. Once a path exists, `FollowingPath` moves strictly toward waypoints with no movement style. It returns to `Direct` only after two consecutive fresh clear line-of-sight checks. Paths expire after 5 seconds and are recalculated when the target moves far enough or the bot gets stuck.

## Dash is a dodge, not a filler

Skills tagged `Escape` are excluded from attack scoring while navigation owns the body (`Pathfinding`, `FollowingPath`, `HoldingDistance`). Outside that, they are allowed in two cases: a real dodge intent (`TARGET_ATTACKING` or `OWN_THREATENED`), or a deliberate combo opener inside its configured distance band (`Distance` and `PreferredDistance` in the bot config). That keeps Dash as an engage tool without turning it into a random gap filler. Emergency dodges still come from the defense layer on an incoming hit and work during pathfinding.

## Stuck recovery

If a bot moves less than 0.3 studs over 0.8 seconds while it is supposed to be moving, recovery runs in two steps: first invalidate line of sight, drop the path and force recalculation; on a repeat, pivot the rig onto the current waypoint (2 studs up), clear velocity, and continue with a 4-second cooldown and at most two teleports per path. A pending path computation falls back to a single jump plus a sidestep.

## A tick in full

```
read sensors -> build condition bitmask -> resolve role from tags
-> update posture -> score actions -> write single action slot
-> run action (skills, movement) -> cleanup
```

## Tuning and gaps

Tune weights and thresholds in bot configuration; use [[Character parameters]] for temporary state. Known gaps: limited long-term memory, simple target selection, and defensive reactions that can overlap during respawns. See [[Known gaps and roadmap]].

Related: [[Combat pipeline]], [[Services and dependencies]], [[Character parameters]].
