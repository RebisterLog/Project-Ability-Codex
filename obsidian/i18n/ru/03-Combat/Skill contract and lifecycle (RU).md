# Контракт и жизненный цикл скилла

Скилл — модуль в `src/server/skills/`, возвращающий таблицу, приблизительно соответствующую `types.SkillData`. Скиллы намеренно **не жёсткие**: каждый определяет свои приватные поля.

## Контракт

| Поле | Обязательно | Примечание |
|---|---|---|
| `DisplayName` | Да | Человекочитаемое имя. |
| `Id` | Устанавливает `SkillService` | Производится от имени модуля. |
| `Cooldown` | Нет | Секунды до повторного применения. |
| `AttackInfo` | Нет | См. [[AttackInfo and AttackData (RU)]]. |
| `SkillCharacters` | Нет | Свободные теги: `"Hit"`, `"Defense"`, `"ComboExtender"`. |
| `onInit` | Нет | Вызывается один раз при добавлении в спек; доступны `self.Character`, `self.Spec`, сервисы. |
| `Activate` | Нет | Вызывается при срабатывании после проверки. |
| `Interrupt` | Нет | Вызывается при стане, рэгдолле или ином прерывании. |

Всё остальное — приватные данные: `ComboCooldown`, `DashProperties`, `PreBarrageInfo`, `Throw` и т.д. Ищите ближайший существующий аналог, а не навязывайте шаблон.

## Заголовок файла

Каждый модуль скилла начинается с блока комментария с именем скилла и секцией `ASSETS`, перечисляющей все анимации, звуки, модели и статы, которые он использует. Это позволяет проверить конфиг скина спека по реальным требованиям.

## Жизненный цикл

- `onInit`: получить сервисы через `Crane:GetService`, кэшировать ассеты через `self:GetAsset(...)`, создать секвенс в `self.Janitor`, инициализировать состояние.
- `Activate`: проиграть секвенс ([[Sequencer (RU)]]) или использовать promise, привязанный к сигналам (паттерн `Block`).
- `Interrupt`: остановить секвенсы и эффекты, освободить параметры.

## Паттерны

| Цель | Пример |
|---|---|
| Минимальный переключатель | `src/server/skills/Run.luau` |
| Один удар с секвенсом | `src/server/skills/Punch.luau` |
| Комбо | `src/server/skills/Punch.luau` |
| Защита / блок | `src/server/skills/Block.luau` |
| Передвижение | `src/server/skills/Dash.luau` |
| Многофазная атака | `src/server/skills/Barrage.luau` |
| Захват / бросок | `src/server/skills/Grab.luau` |

## Регистрация

1. `src/server/skills/<Name>.luau` или `src/server/skills/<Spec>/<Name>.luau`.
2. Путь в спеке: `~/skills/<Name>` или `@Specs/<Spec>/<Name>`. См. [[Spec and SubSpec (RU)]].
3. Бинд в `src/shared/configs/Specs.luau`, если нужен. См. [[Input and BindService (RU)]].

Связанные: [[Create a combat skill (RU)]], [[Sequencer (RU)]], [[Combat pipeline (RU)]]. Оригинал: [[Skill contract and lifecycle]].
