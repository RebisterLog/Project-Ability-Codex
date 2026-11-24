# Реализованные системы

Снимок того, что есть в коде. Перед использованием детали сверяйте с исходниками.

| Система | Состояние | Точка входа |
|---|---|---|
| Ядро боя | Реализовано: хитбоксы, хуки, секвенсы, состояния атак | `src/server/services/CombatService/` |
| Класс и жизненный цикл скилла | Реализовано | `src/server/combat-classes/Skill.luau` |
| Спеки | Реализованы для Gerson, JonathanHamon, Standless, StarPlatinum, TheWorld, Undyne | `src/server/specs/` |
| Скиллы | Реализованы, включая общие и уникальные наборы | `src/server/skills/` |
| Слот SubSpec | Поддерживается слотами и разрешением биндов | [[Spec and SubSpec (RU)]] |
| Репликация VFX | Реализована | `src/server/services/VFXService/`, `src/shared/effects/` |
| Прокси | Реализованы с patch/subscribe | [[Data schemas and Proxy (RU)]] |
| AI ботов | Реализован: слот действия, роли, поза | [[Bot combat AI (RU)]] |
| Квесты | Только минимальный тестовый квест | `src/server/quests/Test/` |
| UI | Компоненты/views на Fusion, stories и Router | `src/client/ui/` |
| Терминальные команды | Реализованы | `src/server/terminal-commands/` |
| Bridge | Реализован, только Studio | [[Bridge (Studio only) (RU)]] |
| Лор | Не написан; только шаблоны и заготовки имён | [[Lore home (RU)]] |
| Инструменты проверки | только `context`, `format`, `impact`; тестового раннера и гейтов нет | [[Formatting and inspection (RU)]] |

Связанные: [[Known gaps and roadmap (RU)]], [[Developer map (RU)]]. Оригинал: [[Implemented systems]].
