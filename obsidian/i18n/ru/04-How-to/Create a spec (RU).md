# Создание спека

Spec — загрузка персонажа. Его создание затрагивает четыре файла и папку ассетов.

## Чек-лист

1. **Модуль спека** — `src/server/specs/<Name>.luau`:
   ```luau
   local Spec = {
       Skills = {
           ["Dash"] = "~/skills/Dash",
           ["Punch"] = "~/skills/Punch",
           ["Unique"] = "@Specs/<Name>/Unique",
       },
       onInit = function(self) end, -- необязательно: прикрепить модели оружия
   }
   return Spec
   ```
2. **Конфиг скина** — `src/shared/configs/Skins/<Name>/None.luau`. Определите `Animations` (`Idle`, `Walk`, `Run` обязательны), `Sounds`, `Models`, `Stats`.
3. **Публичный конфиг** — добавьте запись в `src/shared/configs/Specs.luau` с `DisplayName`, `IsPublic` и `Binds`.
4. **Ассеты** — `ReplicatedStorage.assets.<Name>.None` с `Animations/`, `Sounds/`, `Models/`, `Music/`.
5. **Скиллы** — при необходимости создайте уникальные скиллы в `src/server/skills/<Name>/`. См. [[Create a combat skill (RU)]].
6. **Бинды** — сопоставьте id скилла с клавишей. См. [[Input and BindService (RU)]].

## Правила путей

| Префикс | Значение |
|---|---|
| `~/skills/` | Общий скилл, доступный любому спеке. |
| `@Specs/<Name>/` | Уникальный скилл этого персонажа. |

## Соглашения по ассетам

- Анимации: `Idle`, `Walk`, `Run`, `Punch1`–`Punch4`, `DashForward`/`DashBack`/`DashLeft`/`DashRight`, `Block`, варианты захвата и имена конкретных скиллов. Боевые анимации используют `Enum.AnimationPriority.Action`.
- Звуки: `Punch1`–`Punch4`, `SkillName`, `SkillNameHit`, `SkillNameVL` (голос), звуки захвата.
- Модели: прямые ссылки на инстансы, например `PunchHit`, `Hammer`, `Spear`.
- `Stats.Grab`: `AnimationOffset`, `StartHitFrame`, `EndHitFrame`, `FinalFrame`.

## Проверка

- Все `ASSETS` из заголовка каждого скилла есть в конфиге скина.
- Анимации движения присутствуют; [[Spec and SubSpec (RU)]] делает их атрибутами.
- Бинды не конфликтуют критически; см. [[Input and BindService (RU)]].
- Отформатируйте код: `lune run tools/format.luau --fix --src`. См. [[Formatting and inspection (RU)]].

Связанные: [[Spec and SubSpec (RU)]], [[Create a subspec (RU)]], [[Skill contract and lifecycle (RU)]]. Оригинал: [[Create a spec]].
