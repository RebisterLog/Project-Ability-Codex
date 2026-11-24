# Карта дизайнера

Для дизайнеров и настройщиков, которым нужно понимать, какой параметр за что отвечает. Знание кода не требуется, но пути к файлам указаны, чтобы можно было отправить разработчика в нужное место.

## Начать здесь

1. [[Combat pipeline (RU)]] — путь от нажатия клавиши до попадания.
2. [[Skill contract and lifecycle (RU)]] — что скилл может определять.
3. [[AttackInfo and AttackData (RU)]] — урон, блок, стан, i-frames и состояния результата.
4. [[Character parameters (RU)]] — временные модификаторы персонажа.
5. [[Knockback and movement (RU)]] — как удары двигают тела.
6. [[Spec and SubSpec (RU)]] — как способности группируются в персонажа.

## Карта настройки

| Хочу изменить... | Заметка | Типичный источник |
|---|---|---|
| Числа урона | [[AttackInfo and AttackData (RU)]] | `src/server/skills/` |
| Правила блока / идеального блока | [[Attack hooks (RU)]] | `src/server/services/CombatService/Hooks/` |
| Скорость движения во время скилла | [[Character parameters (RU)]] | `onInit` скилла / кадры секвенса |
| Тайминг комбо | [[Sequencer (RU)]] | `src/server/skills/Punch.luau` |
| Агрессия и защита бота | [[Bot combat AI (RU)]] | `src/server/services/BotService/` |
| Привязки клавиш | [[Input and BindService (RU)]] | `src/shared/configs/Specs.luau` |
| Ассеты скина | [[Create a spec (RU)]] | `src/shared/configs/Skins/` |
| Цели и награды квеста | [[Add a quest (RU)]] | `src/shared/configs/Quests/` |

## Границы

- Комбат **авторитетен на сервере**: изменение только клиентского значения не изменит урон. См. [[Runtime boundaries (RU)]].
- Данные скилла намеренно свободные: скилл может добавлять свои поля. См. [[Skill contract and lifecycle (RU)]].
- Лор ещё не описан; для сюжетных текстов используйте [[Lore map (RU)]].

Оригинал: [[Designer map]].
