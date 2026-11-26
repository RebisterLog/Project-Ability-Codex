# Create a spec

A spec is a character loadout. Creating one touches four files plus Studio-side asset instances.

## Checklist

1. **Spec module** — `src/server/specs/<Name>.luau` (use `const`; configs live at `ReplicatedStorage.shared.configs`, not `Configuration.ConfigsFolder.Value`):
   ```luau
   const ReplicatedStorage = game:GetService("ReplicatedStorage")
   const ServerScriptService = game:GetService("ServerScriptService")
   const types = require(ServerScriptService.server.types)

   const Spec = {
       Skills = {
           ["Dash"] = "~/skills/Dash",
           ["Punch"] = "~/skills/Punch",
           ["Unique"] = "@Specs/<Name>/Unique",
       },
       onInit = function(self: types.Spec) end, -- optional: attach weapon/stand models
   }
   return Spec
   ```
   Use `self.Cleaner:Clone(model)` or `CombatService:Equip(self.Character, model)` (added to `self.Cleaner`) to attach models so they are destroyed with the spec.
2. **Skin config** — `src/shared/configs/Skins/<Name>/None.luau`: use `src/shared/configs/Skins/helpers.luau` factories (`idleAnimation`, `movementAnimation`, `actionAnimation`, `loopedAnimation`, `sound`) and define `Animations` (`Idle`, `Walk`, `Run` are required), `Sounds`, `Models`, optional `VFXs`/`Stand`, and `Stats`.
3. **Public config** — add an entry to `src/shared/configs/Specs.luau` with `DisplayName`, `IsPublic` and a **bind per skill**.
4. **Assets** — `ReplicatedStorage.assets.<Name>.None` with `Animations/`, `Sounds/`, `Models/`, `VFXs/`, `Stand/`. Assets are Studio-only instances; there is no repo asset folder and no `Music/` folder in use.
5. **Skills** — create unique skills under `src/server/skills/<Name>/` if needed. See [[Create a combat skill]].
6. **Binds** — map every skill id to a key/button; a missing bind warns and skips the skill. Every bind is hold-to-cast; there is no `Hold` field. See [[Input and BindService]].

## Path rules

| Prefix | Meaning |
|---|---|
| `~/skills/` | Shared skill, usable by any spec. |
| `@Specs/<Name>/` | Unique skill owned by this spec. |

These values are **naming conventions only** — resolution matches the module name. The spec `Skills` key must equal the skill module's filename.

## Asset conventions

- Animations: `Idle`, `Walk`, `Run`, `Jump`, `FreeFall`, `Punch1`–`Punch4`, `DashForward`/`DashBack`/`DashLeft`/`DashRight`, `Block`, `Grab`/`GrabThrow`/`GrabThrowVictim`, plus skill-specific names. Build each with a helper (`actionAnimation`, `loopedAnimation`, etc.) — do not hand-write `Priority` tables. Stand-on grab variants live under `Stand/Animations/...`.
- Sounds: `Punch1`–`Punch4`, skill-specific names and hit/voice variants, `Grab`, `Grabbed`, `GrabVL`.
- Models: direct references to instances, e.g. `Hammer`, `Spear`, `DashEffect`, `ArmPunchTrail`.
- VFXs / Stand: `VFXs.<Name>` (e.g. `VFXs.Charge`) and `Stand.{Animations,Sounds,Models}`.
- `Stats.Grab` only needs `AnimationOffset` and `FinalFrame`. Keys such as `StartHitFrame`, `EndHitFrame`, `PunchHit` and `StandOffGrab*` are obsolete and are not read by current skins.
- Extra skins are **partial overrides**: `src/shared/configs/Skins/init.luau` recursively merges them into `None`. Non-default skins need explicit `addSkin` ownership and `changeSkin` equip commands.

## Verification

- All `ASSETS` listed in each skill's header exist in the skin config.
- Movement animations are present; [[Spec and SubSpec]] sets them as attributes.
- Binds are present and do not collide badly; see [[Input and BindService]].
- There is no automated test runner. Format with `lune run tools/format.luau --fix --src`, then inspect with `lune run tools/context.luau` and `lune run tools/impact.luau <target>`; playtest in Studio. See [[Formatting and inspection]].

Related: [[Spec and SubSpec]], [[Create a subspec]], [[Skill contract and lifecycle]].
