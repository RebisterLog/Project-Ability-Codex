# Services and dependencies

Services are Crane singletons created with `Crane:CreateService({ Name = "..." })` and accessed with `Crane:GetService("Name")`. Lifecycle callbacks are `onInit` then `onStart`.

## Server services

| Service | Responsibility |
|---|---|
| `CombatService` | `Hitbox`, `Attack`, `CreateSequence`, `CreateGrab`, `AddArmor`, `GetStates`; signals `Casted`, `Attacked`, `Interrupted`; owns the attack hook pipeline. |
| `SkillService` | Loads skills, creates skill instances, handles `StartSkill` / `StopSkill`, cooldowns. |
| `SpecService` | Builds specs from config + module data, assigns binds and skins. |
| `ConfigsService` | Loads `Specs`, `Skins`, bots, quests and other configs. |
| `PlayersService` | Player registry and player-scoped state. |
| `CollisionService` | Collision group registration and assignment. |
| `VFXService` | `StartEffect` / `StopEffect` for Animation, Sound, Particle, Highlight, Hitbox, Ragdoll. |
| `GameDataService` | Persistence of player and game documents. |
| `QuestService` | Quest lifecycle and progression. |
| `BotService`, `BotSpawnService` | NPC controllers and spawning. See [[Bot combat AI]]. |
| `StandService` | Stand-related state for stand specs. |
| `TerminalService` | Developer console commands and hooks. |
| `PathUtil` | Pathfinding helpers. |

## Dependency sketch

```
SkillService  -> SpecService, PathUtil
SpecService   -> ConfigsService, SkillService
CombatService -> VFXService
QuestService  -> GameDataService, ConfigsService
BotService    -> CombatService, PathUtil, ConfigsService
```

Dependencies are fetched by name through Crane rather than passed through constructors. Expect `onInit` ordering to matter when a service is needed during another service's `onStart`.

## Client services

`BindService` (input → packets), `PlayerService` (local player and proxies), `TargetLockService` (target selection), `UIService`, `VFXService` (presentation), `TerminalService`, `BridgeService` (Studio only).

## Related

[[Player and character lifecycle]], [[Combat pipeline]], [[Create a service or component]].
