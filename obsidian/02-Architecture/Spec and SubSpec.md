# Spec and SubSpec

A **spec** is a character loadout: a list of skills, key binds, a skin (animations, sounds, models, stats) and optional init logic. A character can have a main spec (`Spec`) and a secondary slot (`SubSpec`) layered on top.

## Four pieces of a spec

| Piece | Path |
|---|---|
| Spec module | `src/server/specs/<Name>.luau` |
| Skin config | `src/shared/configs/Skins/<Name>/None.luau` (and any other skin folder) |
| Public config | `src/shared/configs/Specs.luau` (`DisplayName`, `IsPublic`, `Binds`) |
| Assets | `ReplicatedStorage.assets.<Name>.<Skin>` with `Animations`, `Sounds`, `Models`, `Music` |

## Skill path rules in a spec module

| Prefix | Meaning | Example |
|---|---|---|
| `~/skills/` | Shared skill available to any spec | `"~/skills/Punch"` |
| `@Specs/<Name>/` | Unique skill for that character | `"@Specs/Undyne/ArcSpearStrike"` |

## Slots and binds

- `SpecSlot` is `"Spec" | "SubSpec"`.
- When several skills share a key, candidates are sorted by slot (`Spec` before `SubSpec`), then alphabetically by skill id. The first candidate that can actually be cast right now receives the key; if none can, the highest-priority candidate keeps it until release.
- There is no `Hold` option. See [[Input and BindService]].

## Construction order

`Character.SetSpec` → `SpecService:CreateSpec` → load spec config and skin → `SkillService:CreateSkill` per skill → `spec:AddSkill(skill)` → assign binds → `Spec.Init` → `Skill.Init`.

## Asset resolution

Skills read assets through `self:GetAsset("Animations/Block")`-style paths relative to `Spec.Data.Assets`, with fallback through the base spec and the `None` skin. Use `TryGetAsset` when a missing asset is acceptable.

## Related

[[Create a spec]], [[Create a subspec]], [[Skill contract and lifecycle]], [[Player and character lifecycle]].
