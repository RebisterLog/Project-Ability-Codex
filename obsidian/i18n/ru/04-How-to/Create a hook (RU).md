# Создание хука

Хуки изменяют каждую атаку через конвейер `Precast` → `Cast` → `Postcast`. Они лежат в `src/server/services/CombatService/Hooks/` и загружаются автоматически.

## Чек-лист

1. Создайте `src/server/services/CombatService/Hooks/<Name>.luau`.
2. Выберите фазу: `Precast` для проверок/состояния, `Cast` для эффектов, `Postcast` для финализации.
3. Зарегистрируйте хук с нужным приоритетом:
   ```luau
   hook:Hook("Precast", "MyHook", priority, function(Data)
       -- изменить AttackData.State
       return true -- false / nil прерывает конвейер
   end)
   ```
4. Всегда возвращайте `true`, если обработка должна продолжиться.
5. Учитывайте порядок: хук, меняющий состояние, должен выполняться до хуков, которые его читают.
6. Проверьте форматирование и зависимости перед коммитом. См. [[Formatting and inspection (RU)]].

## Существующие хуки

`Angular`, `Armor`, `Bleed`, `Block`, `Burn`, `Damage`, `HitFeedback`, `IFrames`, `Knockback`, `NPCOwnership`, `Ragdoll`, `Restand`, `Stun`.

Связанные: [[Attack hooks (RU)]], [[AttackInfo and AttackData (RU)]], [[Combat pipeline (RU)]], [[Create a service or component (RU)]]. Оригинал: [[Create a hook]].
