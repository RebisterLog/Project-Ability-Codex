# Types index

Public types are exported from three places. Prefer importing an existing type over defining a local duplicate.

## `src/server/types.luau`

`PlayerModule`, `Bind`, `SpecSlot`, `SpecInitOptions`, `CleanUp`, `EffectData`, `Parameters`, `ParameterName`, `ParameterValue`, `ParameterObject`, `GrabData`, `HitboxData`, `AttackInfo`, `AttackData`, `ProjectileMoveContext`, `ProjectileMoveFunction`, `ProjectileReflection`, `ProjectileConfig`, `Projectile`, `Quest`, `Stand`, `SkillData`, `Skill`, `SkillReplicationData`, `SpecSaveData`, `SpecDef`, `SpecData`, `Spec`, `PlayerComponent`, `HealData`, `NoDeathEntry`, `Character`.

## `src/client/types.luau`

`ClientPlayerModule`.

## `src/shared/schemas/`

- `GameData.luau` → `GameData`
- `PlayerData.luau` → `PlayerData` (`PlayerDynamicData` + `PlayerSaveData`)
- `PlayerDynamicData.luau` → `SpecSlot`, `CharacterParameters`, `PlayerDynamicData`
- `PlayerSaveData.luau` → `SpecData`, `PlayerSaveData`

## Selected contracts

| Type | Used for |
|---|---|
| `SkillData` | The fields a skill module may define. See [[Skill contract and lifecycle]]. |
| `AttackInfo` / `AttackData` | Attack description and resolution. See [[AttackInfo and AttackData]]. |
| `HitboxData` | Query parameters for `CombatService:Hitbox`. See [[Hitbox and targeting]]. |
| `SpecData` / `SpecDef` | Built spec and its definition. See [[Spec and SubSpec]]. |
| `Character` | Server character component. See [[Player and character lifecycle]]. |

This index is maintained by hand; update it when exported types change.
