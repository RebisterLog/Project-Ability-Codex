# Skill contract and lifecycle

A skill is a module under `src/server/skills/` that returns a table loosely conforming to `types.SkillData`. Skills are intentionally **not** rigid: each defines its own private data fields.

## The contract

| Field | Required | Notes |
|---|---|---|
| `DisplayName` | Yes | Human-readable name; published on `Skill:Init`. |
| `Id` | Set by `SkillService` | Derived from the module filename; must equal the key in the spec's `Skills` table. |
| `Tag` | No | Enablement gate, e.g. `"OnlyForStand"` (toggled with `Spec:SetEnableSkills`). |
| `BaseSpec` | No | Fallback spec id for asset lookup when the skill is shared by several specs. |
| `Cooldown` | Effectively yes | Seconds before reuse; required by the strict type but guarded at runtime. |
| `AttackInfo` | Effectively yes | See [[AttackInfo and AttackData]]; required by the strict type but guarded at runtime. |
| `SkillCharacters` | No | Typed bot tags from `src/shared/bot-characters.luau`, e.g. `"Hit"`, `"Stun"`, `"Blockable"`, `"PerfectBlock"`, `"BlockBreak"`. |
| `onInit` | No | Called by `Skill:Init` when added to a spec; access `self.Character`, `self.Spec` and services. |
| `onDestroy` | No | Called by `Skill:Destroy` before the cleaner is destroyed. |
| `Activate` | No | Called when the skill fires after validation. |
| `Interrupt` | No | Called only while `Active`, normally via the `CombatService.Interrupted` connection set up by `Skill:Init`. |

Everything else is private skill data: `ComboCooldown`, `DashProperties`, `PreBarrageInfo`, `Throw`, `Checks` (a private table read by `Skill:Validate`), and so on. Look for the closest existing analog instead of forcing a template.

In practice `Cooldown` is optional: skills that start their cooldown manually — `MarkedKnives` on a `KnivesCharge` spend and Distant Slam once a marked target is found — declare `Cooldown = 0` and call `self:SetCooldown(...)` themselves. Other optional skill-data fields used by current skills are `AimRequired`, `UseCooldown`, `SearchRadius`, `Hitbox`, `BarrageInfo`, `PostBarrageInfo` and `ProjectileData`. These are typed metadata that the skills read themselves; the engine does not enforce them. Discrete knife charges are an ordinary entry in `shared/configs/Charges.luau` and are spent through `CombatService:GetCharge/ConsumeCharge`, not a separate ammo system.

`SkillCharacters` values are an enum, not free text. Prefer the canonical `"PerfectBlock"` and `"BlockBreak"`; the aliases `PerfectBlockable` / `BlockBreaker` are legacy. `OnlyForStand` is a `Tag`, not a SkillCharacter.

## File header convention

Every skill module starts with a block comment named after the skill and an `ASSETS` section listing every animation, sound, model and stat it uses. This lets a spec's skin config be checked against actual requirements.

## Lifecycle notes

- `Skill.new` gives every skill `self.Cleaner = Crane.Buttler.new()`. There is no `self.Janitor` field; sequence-local objects go in `seq.Cleaner`, skill-lifetime objects in `self.Cleaner`.
- `onInit`: fetch services with `Crane:GetService`, cache assets with `self:GetAsset(...)`, create the sequence with `self.Cleaner:Add(...)`, initialise state. `Skill:Init` also enables untagged skills (`Tag == nil`) and connects `CombatService.Interrupted` **only if** `Interrupt` exists.
- `Activate`: guards `Active`, sets `Holding`, adds a `CastingSkill` parameter, runs `Data.Activate` under `xpcall`, then applies `Data.Cooldown` (multiplied by the character's `CooldownMultiplier`). Every bind is hold-to-cast, so long casts release on `self.Deactivated`.
- `Interrupt`: stop the sequence and let the cleaners release parameters/effects. The `CombatService.Interrupted` connection means you usually do not add your own.
- `GetAsset("Animations/Name")` reads slash-separated keys from the merged skin (`Spec.Data.Assets`), falling back to `BaseSpec`'s skin. It warns and errors loudly on a missing required asset; `TryGetAsset` returns `nil` silently.
- `Skill:Validate` rejects casts when casting is disabled (`NoSkillCast`), the skill is disabled, a `Stun`/`Ragdoll`/`Dead` check fails, `Metadata.IsGrounded` disagrees with `Checks.IsGrounded`, `Restand` is set, or the skill is on cooldown.

## Patterns to copy

| Goal | Look at |
|---|---|
| Canonical stub | `src/server/skills/TEMPLATE.luau` |
| Minimal/simple toggle | `src/server/skills/Run.luau` |
| Single hit with sequence | `src/server/skills/Undyne/ArcSpearStrike.luau` |
| Combo | `src/server/skills/Punch.luau` |
| Defense / block (promise over signals) | `src/server/skills/Block.luau` |
| Mobility | `src/server/skills/Dash.luau` |
| Multi-phase / repeated hits | `src/server/skills/Barrage.luau` |
| Grab / throw | `src/server/skills/Grab.luau` |

## Registration

1. Create `src/server/skills/<Name>.luau` or `src/server/skills/<Spec>/<Name>.luau`.
2. Add the module key to the spec module's `Skills` table; the key **must equal the filename**. The `~/skills/<Name>` or `@Specs/<Spec>/<Name>` value is a naming convention only. See [[Spec and SubSpec]].
3. Add a bind in `src/shared/configs/Specs.luau` — it is **required**; an unbound skill warns and is skipped. See [[Input and BindService]].

Related: [[Create a combat skill]], [[Sequencer]], [[Combat pipeline]].
