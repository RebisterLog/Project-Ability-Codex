# Создание спека

Spec — это загрузка персонажа. Его создание затрагивает четыре файла и инстансы ассетов на стороне Studio.

## Чек-лист

1. **Модуль спека** — `src/server/specs/<Name>.luau` (используйте `const`; конфиги находятся в `ReplicatedStorage.shared.configs`, а не в `Configuration.ConfigsFolder.Value`):
   ```luau
   const ReplicatedStorage = game:GetService("ReplicatedStorage")
   const ServerScriptService = game:GetService("ServerScriptService")
   const types = require(ServerScriptService.server.types)

   const Spec = {
       Skills = {
           ["Dash"] = "~/skills/Dash",
           ["Punch"] = "~/skills/Punch",
           ["Unique"] = "@Specs/<Name>/Unique",
       },
       onInit = function(self: types.Spec) end, -- необязательно: прикрепить модели оружия/стэнда
   }
   return Spec
   ```
   Чтобы прикрепить модели, используйте `self.Cleaner:Clone(model)` или `CombatService:Equip(self.Character, model)` (добавляется в `self.Cleaner`) — тогда они будут уничтожены вместе с спеком.
2. **Конфиг скина** — `src/shared/configs/Skins/<Name>/None.luau`: используйте фабрики из `src/shared/configs/Skins/helpers.luau` (`idleAnimation`, `movementAnimation`, `actionAnimation`, `loopedAnimation`, `sound`) и определите `Animations` (`Idle`, `Walk`, `Run` обязательны), `Sounds`, `Models`, необязательные `VFXs`/`Stand` и `Stats`.
3. **Публичный конфиг** — добавьте запись в `src/shared/configs/Specs.luau` с `DisplayName`, `IsPublic` и **биндом на каждый скилл**.
4. **Ассеты** — `ReplicatedStorage.assets.<Name>.None` с папками `Animations/`, `Sounds/`, `Models/`, `VFXs/`, `Stand/`. Ассеты — инстансы только в Studio; папки ассетов в репозитории нет, `Music/` не используется.
5. **Скиллы** — при необходимости создайте уникальные скиллы в `src/server/skills/<Name>/`. См. [[Create a combat skill (RU)]].
6. **Бинды** — сопоставьте каждый id скилла с клавишей/кнопкой; отсутствующий бинд вызывает предупреждение, и скилл пропускается. Все бинды — hold-to-cast, поля `Hold` нет. См. [[Input and BindService (RU)]].

## Правила путей

| Префикс | Значение |
|---|---|
| `~/skills/` | Общий скилл, доступный любому спеку. |
| `@Specs/<Name>/` | Уникальный скилл этого персонажа. |

Эти значения — **лишь соглашение об именах**: разрешение сверяется с именем модуля. Ключ `Skills` в спеке должен совпадать с именем файла скилла.

## Соглашения по ассетам

- Анимации: `Idle`, `Walk`, `Run`, `Jump`, `FreeFall`, `Punch1`–`Punch4`, `DashForward`/`DashBack`/`DashLeft`/`DashRight`, `Block`, `Grab`/`GrabThrow`/`GrabThrowVictim` плюс имена конкретных скиллов. Создавайте каждую через фабрику (`actionAnimation`, `loopedAnimation` и т. д.) — не пишите таблицы `Priority` вручную. Варианты захвата стэндом находятся в `Stand/Animations/...`.
- Звуки: `Punch1`–`Punch4`, имена конкретных скиллов и варианты попадания/голоса, `Grab`, `Grabbed`, `GrabVL`.
- Модели: прямые ссылки на инстансы, например `Hammer`, `Spear`, `DashEffect`, `ArmPunchTrail`.
- VFXs / Stand: `VFXs.<Name>` (например, `VFXs.Charge`) и `Stand.{Animations,Sounds,Models}`.
- `Stats.Grab` нуждается только в `AnimationOffset` и `FinalFrame`. Такие ключи, как `StartHitFrame`, `EndHitFrame`, `PunchHit` и `StandOffGrab*`, устарели и текущими скинами не читаются.
- Дополнительные скины — **частичные переопределения**: `src/shared/configs/Skins/init.luau` рекурсивно сливает их в `None`. Нестандартные скины требуют явного назначения владельца через `addSkin` и экипировки через `changeSkin`.

## Проверка

- Все `ASSETS` из заголовка каждого скилла присутствуют в конфиге скина.
- Анимации движения присутствуют; [[Spec and SubSpec (RU)]] задаёт их как атрибуты.
- Бинды присутствуют и не конфликтуют критически; см. [[Input and BindService (RU)]].
- Автоматического test runner нет. Отформатируйте код командой `lune run tools/format.luau --fix --src`, затем проверьте через `lune run tools/context.luau` и `lune run tools/impact.luau <target>`; протестируйте в Studio. См. [[Formatting and inspection (RU)]].

Связанные: [[Spec and SubSpec (RU)]], [[Create a subspec (RU)]], [[Skill contract and lifecycle (RU)]]. Оригинал: [[Create a spec]].
