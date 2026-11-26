# Spec and SubSpec

A **spec** is a character loadout: a list of skills, key binds, a skin (animations, sounds, models, stats) and optional init logic. A character can have a main spec (`Spec`) and a secondary slot (`SubSpec`) layered on top.

## Four pieces of a spec

| Piece | Path |
|---|---|
| Spec module | `src/server/specs/<Name>.luau` (`Skills`, optional typed `onInit`) |
| Skin config | `src/shared/configs/Skins/<Name>/None.luau` (and any other skin folder) |
| Public config | `src/shared/configs/Specs.luau` (`DisplayName`, `IsPublic`, optional `Type`, `Binds`) |
| Assets | `ReplicatedStorage.assets.<Name>.<Skin>` with `Animations`, `Sounds`, `Models`, `VFXs`, `Stand` (Studio-only; no `Music` folder) |

## Skill path rules in a spec module

| Prefix | Meaning | Example |
|---|---|---|
| `~/skills/` | Shared skill available to any spec | `"~/skills/Punch"` |
| `@Specs/<Name>/` | Unique skill for that character | `"@Specs/Undyne/ArcSpearStrike"` |

These values are **naming conventions only** — `SkillService:CreateSkill` matches the module name, never dereferences the string. The `Skills` key must equal the skill module's filename.

## Slots and binds

- `SpecData.Slot` is `"Spec" | "SubSpec"`, stamped from `Type = "SubSpec"` in `src/shared/configs/Specs.luau` — that config is the single source of truth (`SpecService:GetSpecType`).
- `Character.SetSpec` calls `created:Init({ Movement = slot == "Spec" })`, so the main spec owns body movement animations and a subspec does not.
- When several skills share a key, candidates are sorted by slot (`Spec` before `SubSpec`), then alphabetically by skill id. The first candidate that can actually be cast right now receives the key; if none can, the highest-priority candidate keeps it until release.
- Every skill needs a bind: a missing bind warns and is skipped. There is no `Hold` option — every bind is hold-to-cast. See [[Input and BindService]].

## Construction order

`Character.SetSpec` (`Character/init.luau:187-220`) → `SpecService:CreateSpec` (`:74-120`: load merged config and skin, `SkillService:CreateSkill` per skill, `spec:AddSkill(skill)`, assign binds) → `Spec.Init` (`:37-63`: set movement animation attributes, then call the spec's `onInit`) → `Skill.Init` (`:172-192`: call each skill's `onInit`). `CreateSpec` itself does **not** call `Init`.

## Asset resolution

Skills read assets through `self:GetAsset("Animations/Block")`-style paths relative to the merged skin `Spec.Data.Assets`, with fallback to the skill's `BaseSpec` skin. There is no per-path `None` fallback inside `GetAsset` — `None` is simply the default skin name. Use `TryGetAsset` (with an `or default`) when a missing asset is acceptable.

## Related

[[Create a spec]], [[Create a subspec]], [[Skill contract and lifecycle]], [[Player and character lifecycle]].
