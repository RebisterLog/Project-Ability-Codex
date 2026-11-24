# Add a quest

Quests combine a server quest module with shared config data.

## Checklist

1. Create `src/server/quests/<Name>.luau` implementing the quest contract: start, objective updates, completion, failure, rewards.
2. Create `src/shared/configs/Quests/<Name>.luau` with display name, description, objectives and rewards.
3. Register the quest with `QuestService` if registration is not automatic in your branch.
4. Wire objective triggers to existing systems (spec changes, kills, interactions) rather than duplicating game logic.
5. Persist progression through `GameDataService` / player save data. See [[Data schemas and Proxy]].
6. Add a UI entry if the quest needs tracking. See [[Create a UI element]].

## Existing seed

A `Test` quest exists under `src/server/quests/Test/` and `src/shared/configs/Quests/Test/`. Use it as the minimal working example; its lore text is a placeholder. See [[Quest seeds]].

## Verification

- Starting, progressing and completing the quest each update the expected proxy/data fields.
- Failure and abandonment clean up objective listeners.
- `lune run tools/format.luau --fix --src`.

Related: [[Services and dependencies]], [[Lore home]], [[Quest template]].
