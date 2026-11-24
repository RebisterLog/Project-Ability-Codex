# Skill contract and lifecycle

A skill is a module under `src/server/skills/` that returns a table loosely conforming to `types.SkillData`. Skills are intentionally **not** rigid: each defines its own private data fields.

## The contract

| Field | Required | Notes |
|---|---|---|
| `DisplayName` | Yes | Human-readable name. |
| `Id` | Set by `SkillService` | Derived from the module name. |
| `Cooldown` | No | Seconds before reuse. |
| `AttackInfo` | No | See [[AttackInfo and AttackData]]. |
| `SkillCharacters` | No | Freeform tags such as `"Hit"`, `"Defense"`, `"ComboExtender"`. |
| `onInit` | No | Called once when added to a spec; access `self.Character`, `self.Spec` and services. |
| `Activate` | No | Called when the skill fires after validation. |
| `Interrupt` | No | Called when the character is stunned, ragdolled or otherwise interrupted. |

Everything else is private skill data: `ComboCooldown`, `DashProperties`, `PreBarrageInfo`, `Throw`, and so on. Look for the closest existing analog instead of forcing a template.

## File header convention

Every skill module starts with a block comment named after the skill and an `ASSETS` section listing every animation, sound, model and stat it uses. This lets a spec's skin config be checked against actual requirements.

## Lifecycle notes

- `onInit`: fetch services with `Crane:GetService`, cache assets with `self:GetAsset(...)`, create the sequence, initialise state.
- `Activate`: play the sequence, toggle a state, or use a promise attached to signals (the `Block` pattern).
- `Interrupt`: stop sequences, stop VFX, release parameters.

## Patterns to copy

| Goal | Look at |
|---|---|
| Minimal/simple toggle | `src/server/skills/Run.luau` |
| Single hit with sequence | `src/server/skills/Punch.luau` |
| Combo | `src/server/skills/Punch.luau` |
| Defense / block | `src/server/skills/Block.luau` |
| Mobility | `src/server/skills/Dash.luau` |
| Multi-phase attack | `src/server/skills/Barrage.luau` |
| Grab / throw | `src/server/skills/Grab.luau` |

## Registration

1. Create `src/server/skills/<Name>.luau` or `src/server/skills/<Spec>/<Name>.luau`.
2. Add it to the spec module with `~/skills/<Name>` or `@Specs/<Spec>/<Name>`. See [[Spec and SubSpec]].
3. Add a bind in `src/shared/configs/Specs.luau` if needed. See [[Input and BindService]].

Related: [[Create a combat skill]], [[Sequencer]], [[Combat pipeline]].
