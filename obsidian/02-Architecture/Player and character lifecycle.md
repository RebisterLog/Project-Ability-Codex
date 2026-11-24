# Player and character lifecycle

## Join to playable character

| Stage | Where | What happens |
|---|---|---|
| 1. Player joins | server `PlayersService` / `GameDataService` | Document data is loaded. |
| 2. Player component | `src/server/components/Player.luau` | Player state becomes available; `InitModules()` runs server player modules. |
| 3. Character creation | `src/server/player-modules/CharacterAdder.luau` | Character model and `Character` component are attached. |
| 4. Spec selection | `src/server/components/Character/init.luau` → `SetSpec` | Calls `SpecService:CreateSpec`. |
| 5. Spec construction | `src/server/services/SpecService.luau` | Merges config + spec module + skin, creates each skill via `SkillService:CreateSkill`, assigns binds, calls `spec:AddSkill`. |
| 6. Spec init | `src/server/combat-classes/Spec.luau` | Sets movement animations (`Idle`, `Walk`, `Run`) as attributes, calls `Data.onInit`. |
| 7. Skill init | `src/server/combat-classes/Skill.luau` | Calls the skill's `onInit`, connects `Interrupt` to `CombatService.Interrupted`. |
| 8. Client setup | `src/client/components/Player.luau` | After proxies arrive, `PlayerService.onInit` runs client player modules; `onCharacter` runs on spawn/respawn. |

## Cleanup and respawn

- Player modules receive a scoped `Cleaner` (Crane Buttler); release connections and spawned instances there. See [[Player modules]].
- Skills own a `Janitor`; sequences own `seq.Cleaner`. Interrupt must stop sequences and effects. See [[Skill contract and lifecycle]].
- After repeated respawns, more than one `Character` component may be present on the same model. Do not assume a single component; see [[Gotchas]].

## Related

[[Spec and SubSpec]], [[Data schemas and Proxy]], [[Input and BindService]].
