# PAC Bot AI

How a bot decides what to do. Everything below is implemented in
`src/server/services/BotService/` and is covered by
`tools/tests/bot-skill-priority.luau`.

## The one idea: a single action slot

`Spec:ActivateSkill` returns early while **any** skill is active, and
`Skill:Activate` returns early while the skill itself is active. A bot can
therefore perform exactly one thing at a time, and every decision is really a
decision about **who owns the slot**: the attack or the defense.

This single fact explains most of the design:

- The guard must not compete with attacks on weights. On a tie it would win and
  occupy the slot, and a guard pressed late gives no perfect block, because the
  window is stamped at activation time (`Block.luau`, `CombatService:GetStates`).
- Defense is event driven and attack is polled. Perfect block has a 0.25s window
  that is stamped by a fresh press, so the decision has to happen in the frame of
  the impact, not on the next tick.
- While the guard is held, the attack layer does nothing at all.

## Layers

```
BotService/
 Bot.luau        facade: target, navigation, owns the slot, one Heartbeat tick
 Defense.luau    pure rules of the defense layer (no Roblox calls at all)
 Attack.luau     attack layer: combo progression and skill selection
 Sense.luau      perception: distance and a mask of target conditions
 Threat.luau     reaction to incoming hitboxes
 Posture.luau    how the bot stands and what distance it keeps
 Conditions.luau condition vocabulary as a bitmask
 SkillPriority.luau scoring of skills against the config
```

`Defense`, `Attack`, `SkillPriority` and `Conditions` are free of Roblox calls,
which is why the interesting rules can be verified under `lune` instead of by
watching bots fight in Studio.

### Conditions are a bitmask

`Sense` produces a single number: bit *n* means condition *n* is met. Conditions
are evaluated every tick for every skill, and `table.find` over an array of
strings costs O(conditions × skills) string comparisons; a bitwise AND is one
operation and allocates nothing. Condition lists coming from configs are
converted to masks once and cached.

`Conditions` deliberately duplicates the vocabulary of
`shared/bot-characters.luau` so the same file loads in Studio and in `lune`. The
test suite compares the two vocabularies in both directions, so they cannot drift
apart silently.

## Roles come from tags, not from config

`Defense.ResolveRoles` reads the `SkillCharacters` tags of every skill of the
spec:

| Tags | Role |
|---|---|
| `Defense` | the guard, the held shield |
| `Defense` + `Escape` | the retreat |
| `Defense` + `Counter` | not a defense role at all: a counter attack is offence |
| anything else | an ordinary attacking skill |

A spec without a `Defense` skill simply has no guard, and its defense degrades to
retreating.

### Guard versus counter

Both look defensive, but they behave completely differently and that is the whole
reason for the split:

- **`Block` is held.** It stays active while the bot keeps it, and the perfect
  block window is refreshed only by a fresh press. A held guard therefore owns the
  slot until something releases it.
- **`Counter` is a one-shot answer.** 45 frames of window, 6 seconds of cooldown,
  and it throws the attacker back. Semantically it is a strike, not a shield, and
  it stays an ordinary candidate of the attack layer even though it is absent from
  every combo.

## Posture instead of a state machine

The bot used to run a state machine with `Attacking` and `Defending` states. The
states differed only by posture (movement style and held distance) and the
transitions held the actual logic, which is why a forgotten `return` once made the
bot dash away right after blocking.

Now the posture is data:

| Posture | Style | Hold distance |
|---|---|---|
| `Idle` | `direct` | none |
| `Attack` | `puma` or `zigzag`, rolled per entry | none |
| `Defend` | `zigzag` | 15 |

`Bot:SetPosture` applies a posture, and leaving `Defend` releases the guard, so the
slot is free for the attack again.

## Defense: two entry points

### 1. An incoming hit, immediately

`CombatService.Casted` fires before `CombatService:Attack` computes the states of
the victim, which is where perfect block versus normal block is decided. So
`Bot:OnIncoming` runs inside that signal and never waits for a tick.

`Threat:Track` decides whether the hitbox is actually coming at the bot: it has to
be inside `hitbox size + lead` and, except for the very first sighting, it has to
be approaching. Projectiles get a much larger lead because they travel.

`Defense.React` then returns one of four decisions:

| Decision | When | Effect |
|---|---|---|
| `Press` | blockable hit, guard free | fresh press, the perfect-block window is stamped now |
| `Hold` | blockable hit, guard already held | nothing, an active `Block` does not restart |
| `Escape` | nothing blockable, or the guard is on cooldown | retreat skill |
| `Ignore` | a spec without any defense skill | nothing |

The press is wrapped in `task.spawn`, because `Skill:Activate` yields and the
guard state has to settle before the states of the victim are computed.

### 2. Guard release, on the tick

While the guard is held, `Defense.ShouldReleaseGuard` runs every tick:

1. `TARGET_PERFECT_BLOCKABLE` in the mask releases it immediately, regardless of
   the config. A held guard does not refresh the perfect-block window, so the
   fresh press has to happen on the impact frame instead.
2. Otherwise the config decides through `HoldUntil` (emergency abort) and
   `HoldWhile` (keep holding while at least one condition is met).

Releasing the guard *before* the impact is what makes `Press` possible in time.

## Attack: combos plus scoring

`Attack.Step` runs on the tick and does nothing at all while a skill is active.

Candidates are every skill of the spec that passes `Skill:Validate`, minus the
guard. A combo is rolled once per fight, and its current step gets `ComboWeight`,
which also wins every tie: the combo is the backbone, conditions only shift it
when they offer a strict advantage.

`SkillPriority.Select` scores each candidate:

```
score = Priority
      + ConditionWeight × (matched PreferredConditions − matched PenaltyConditions)
      + ConditionWeight × 1 if the distance is inside PreferredDistance
      + ComboWeight      if the skill is the current combo step
```

A skill is excluded outright by the hard filters: `Distance`,
`RequiredConditions` and `ForbiddenConditions`. Deviating from the plan does not
advance the combo index, the plan simply loses for this tick.

## When does the bot defend

`Defense.ShouldDefend` is the whole posture gate:

```
defend = a hit landed recently, or TARGET_BLOCKABLE / TARGET_PERFECT_BLOCKABLE
```

"The target is winding up an attack" is deliberately **not** the trigger:

- A target holding its own block stays active forever, and using "has an active
  skill" made the bot retreat from it for the rest of the fight.
- A parryable or unblockable hit (`Grab`, `CircularKick`) is answered with a
  counter attack, not with a retreat. Guarding against it would also mute the
  counter entirely, because its only hard condition is `TARGET_ATTACKING` and that
  same condition used to send the bot into the defense, where there is no attack
  layer.

## A tick in full

```
Heartbeat (accumulated to 1/30s so behaviour does not depend on FPS)
  no target?                     -> posture Idle
  Sense.Refresh()                 -> mask + distance
  guard held and should release? -> release it
  ShouldDefend(mask, recentHit)? -> posture Defend, return
  posture Attack
  Attack.Step()
```

## Tuning a bot

`src/shared/configs/Bots/*.luau`:

| Field | Effect |
|---|---|
| `Distance` | hard maximum range of the skill |
| `RequiredConditions` | all of them must be met |
| `ForbiddenConditions` | none of them may be met |
| `PreferredConditions`, `PenaltyConditions` | soft scoring, ±`ConditionWeight` each |
| `PreferredDistance` | soft band, +`ConditionWeight` inside |
| `Priority` | flat offset, for when conditions cannot separate two skills |
| `HoldWhile`, `HoldUntil` | when the guard is kept and when it is dropped |
| `Combos` | plans; a step in the plan gets `ComboWeight` |
| `Chaotic`, `Aggressive`, `Agility` | spread of the attack movement style |

Two rules worth keeping:

- A skill listed in `Combos` must also be described in `Skills`, otherwise the
  allowlist cuts it and it never fires.
- `Block.HoldUntil` must contain `TARGET_PERFECT_BLOCKABLE`, otherwise the bot
  silently loses perfect blocks. Both are asserted by the test suite.

## Known gaps

- `BotsService:Remove` calls `Cleaner:Cleanup()`, which `Crane.Buttler` does not
  have (`Clean` and `Destroy` exist), and `self.Bots` is never filled in, so bots
  are not removed through that path.
- Bitwise operations go through `bit32` instead of the `&`, `|` and `<<`
  operators: the formatter version used in this repository panics on them.
- The formatter also cannot parse `|=`, so masks are built with explicit
  assignments.