# Указатель типов

Публичные типы экспортируются из трёх мест. Импортируйте существующий тип, а не создавайте локальный дубликат.

## `src/server/types.luau`

`PlayerModule`, `Bind`, `SpecSlot`, `SpecInitOptions`, `CleanUp`, `EffectData`, `Parameters`, `ParameterName`, `ParameterValue`, `ParameterObject`, `GrabData`, `HitboxData`, `AttackInfo`, `AttackData`, `ProjectileMoveContext`, `ProjectileMoveFunction`, `ProjectileReflection`, `ProjectileConfig`, `Projectile`, `Quest`, `Stand`, `SkillData`, `Skill`, `SkillReplicationData`, `SpecSaveData`, `SpecDef`, `SpecData`, `Spec`, `PlayerComponent`, `HealData`, `NoDeathEntry`, `Character`.

## `src/client/types.luau`

`ClientPlayerModule`.

## `src/shared/schemas/`

- `GameData.luau` → `GameData`
- `PlayerData.luau` → `PlayerData` (`PlayerDynamicData` + `PlayerSaveData`)
- `PlayerDynamicData.luau` → `SpecSlot`, `CharacterParameters`, `PlayerDynamicData`
- `PlayerSaveData.luau` → `SpecData`, `PlayerSaveData`

## Избранные контракты

| Тип | Для чего |
|---|---|
| `SkillData` | Поля, которые может определить модуль скилла. См. [[Skill contract and lifecycle (RU)]]. |
| `AttackInfo` / `AttackData` | Описание и результат атаки. См. [[AttackInfo and AttackData (RU)]]. |
| `HitboxData` | Параметры запроса `CombatService:Hitbox`. См. [[Hitbox and targeting (RU)]]. |
| `SpecData` / `SpecDef` | Собранный спек и его определение. См. [[Spec and SubSpec (RU)]]. |
| `Character` | Серверный компонент персонажа. См. [[Player and character lifecycle (RU)]]. |

Указатель ведётся вручную; обновляйте его при изменении экспортируемых типов. Оригинал: [[Types index]].
