# Create a spec

A spec is a character loadout. Creating one touches four files plus an asset folder.

## Checklist

1. **Spec module** — `src/server/specs/<Name>.luau`:
   ```luau
   local Spec = {
       Skills = {
           ["Dash"] = "~/skills/Dash",
           ["Punch"] = "~/skills/Punch",
           ["Unique"] = "@Specs/<Name>/Unique",
       },
       onInit = function(self) end, -- optional: attach weapon models
   }
   return Spec
   ```
2. **Skin config** — `src/shared/configs/Skins/<Name>/None.luau`. Define `Animations` (`Idle`, `Walk`, `Run` are required), `Sounds`, `Models`, `Stats`.
3. **Public config** — add an entry to `src/shared/configs/Specs.luau` with `DisplayName`, `IsPublic` and `Binds`.
4. **Assets** — `ReplicatedStorage.assets.<Name>.None` with `Animations/`, `Sounds/`, `Models/`, `Music/`.
5. **Skills** — create unique skills under `src/server/skills/<Name>/` if needed. See [[Create a combat skill]].
6. **Binds** — map each skill id to a key/button. See [[Input and BindService]].

## Path rules

| Prefix | Meaning |
|---|---|
| `~/skills/` | Shared skill, usable by any spec. |
| `@Specs/<Name>/` | Unique skill owned by this spec. |

## Asset conventions

- Animations: `Idle`, `Walk`, `Run`, `Punch1`–`Punch4`, `DashForward`/`DashBack`/`DashLeft`/`DashRight`, `Block`, grab variants, plus skill-specific names. Combat animations use `Enum.AnimationPriority.Action`.
- Sounds: `Punch1`–`Punch4`, `SkillName`, `SkillNameHit`, `SkillNameVL` (voice line), grab sounds.
- Models: direct references to instances, e.g. `PunchHit`, `Hammer`, `Spear`.
- `Stats.Grab`: `AnimationOffset`, `StartHitFrame`, `EndHitFrame`, `FinalFrame`.

## Verification

- All `ASSETS` listed in each skill's header exist in the skin config.
- Movement animations are present; [[Spec and SubSpec]] sets them as attributes.
- Binds do not collide badly; see [[Input and BindService]].
- Run `lune run tools/format.luau --fix --src`. See [[Formatting and inspection]].

Related: [[Spec and SubSpec]], [[Create a subspec]], [[Skill contract and lifecycle]].
