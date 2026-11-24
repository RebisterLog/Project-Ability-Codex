# Designer map

For designers and tuners who need to understand which knob changes what behaviour. Code knowledge is not required, but file paths are included so you can point a developer at the right place.

## Start here

1. [[Combat pipeline]] — the end-to-end path from a key press to a hit.
2. [[Skill contract and lifecycle]] — what a skill is allowed to define.
3. [[AttackInfo and AttackData]] — damage, block, stun, i-frames and result states.
4. [[Character parameters]] — temporary character-wide modifiers.
5. [[Knockback and movement]] — how hits move bodies.
6. [[Spec and SubSpec]] — how abilities are grouped into a character.

## Tuning map

| I want to change... | Note | Typical source |
|---|---|---|
| Damage numbers | [[AttackInfo and AttackData]] | `src/server/skills/` |
| Block / perfect block rules | [[Attack hooks]] | `src/server/services/CombatService/Hooks/` |
| Movement speed during a skill | [[Character parameters]] | skill `onInit` / sequence frames |
| Combo timing | [[Sequencer]] | `src/server/skills/Punch.luau` |
| Bot aggression and defense | [[Bot combat AI]] | `src/server/services/BotService/` |
| Key bindings | [[Input and BindService]] | `src/shared/configs/Specs.luau` |
| Visual/sound assets per skin | [[Create a spec]] | `src/shared/configs/Skins/` |
| Quest objectives and rewards | [[Add a quest]] | `src/shared/configs/Quests/` |

## Boundaries to keep in mind

- Combat is **server-authoritative**: changing a client value alone will not change damage. See [[Runtime boundaries]].
- Skill data is intentionally freeform: a skill may add its own fields. See [[Skill contract and lifecycle]].
- Lore is not defined yet; use [[Lore map]] templates for any story or character text.
