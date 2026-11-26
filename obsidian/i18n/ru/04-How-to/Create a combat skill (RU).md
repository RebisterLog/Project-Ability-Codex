# Создание боевого скилла

## Чек-лист

1. **Выберите ближайший аналог** из [[Skill contract and lifecycle (RU)]] — скиллы намеренно не шаблонные; каноническая заглушка — `src/server/skills/TEMPLATE.luau`.
2. **Комментарий-заголовок**: имя скилла, краткое описание и блок `ASSETS` со всеми анимациями, звуками, моделями и статами, которые использует скилл.
3. **Форма модуля**:
   ```luau
   const Skill: types.SkillData = {
       DisplayName = "<Name>",   -- обязательно
       Cooldown = 2,
       SkillCharacters = { "Hit" }, -- типизированные теги ботов, не произвольный текст
   }
   function Skill.onInit(self) end
   function Skill.Activate(self) end
   function Skill.Interrupt(self) end
   return Skill
   ```
4. **onInit**: получить сервисы через `Crane:GetService`, прочитать ассеты через `self:GetAsset("Animations/...")`, создать секвенс в `self.Cleaner` (`Crane.Buttler`), инициализировать состояние.
5. **Activate**: проиграть секвенс ([[Sequencer (RU)]]) или использовать promise, привязанный к сигналам. На кадрах попадания вызвать [[Hitbox and targeting (RU)]], пропустить уже поражённые цели, вызвать `CombatService:Attack` с [[AttackInfo and AttackData (RU)]]. Повторяющиеся попадания задаются ключами кадра `Interval = N` / `Offset = M`, валидатор секвенса называется `Validator`. Каждый бинд — hold-to-cast, поэтому долгие касты завершают по `self.Deactivated`, а не по одному нажатию.
6. **Interrupt**: остановить секвенс; остановку эффектов обычно один раз регистрируют в `seq.Cleaner` на кадре 0, а не повторяют здесь. Обычно ничего не нужно: `Skill:Init` сам подключает `CombatService.Interrupted`, если есть `Interrupt`.
7. **Регистрация**: добавить ключ в таблицу `Skills` спека (`~/skills/<Name>` или `@Specs/<Spec>/<Name>`) и обязательный бинд. Имя файла = `Id` = ключ в `Skills`; строковые значения — лишь соглашение об именах. См. [[Spec and SubSpec (RU)]], [[Input and BindService (RU)]].

## Соглашения

- Боевая логика остаётся на сервере. См. [[Runtime boundaries (RU)]].
- Скилл владеет `self.Cleaner` (`Crane.Buttler`), **не** `self.Janitor`; `seq.Cleaner` — тоже Butler. Ресурсы со сроком жизни скилла идут в `self.Cleaner`, ресурсы кадра — в `seq.Cleaner`.
- `SkillCharacters` — типизированные теги ботов из `src/shared/bot-characters.luau` (`"Hit"`, `"Stun"`, `"Blockable"`, `"BlockBreak"`, ...), а не произвольный текст. `OnlyForStand` — это отдельное поле `Tag`, а `Checks` — приватная таблица, которую читает `Skill:Validate`.
- На секвенсе валидатор — `Validator` (не `Validate`); повторяющиеся попадания задаются `Interval = N` / `Offset = M`, а не `if frame % N ~= 0 then return end`. Диапазонный кадр — не цикл. См. [[Sequencer (RU)]].
- `VFXService:StartEffect/StopEffect` принимают ровно три аргумента: `(players, name, dataTable)`. Позиционного `RootPart` или анимации нет; стоп анимации берёт `clip.Animation`, старт — таблицу клипа.
- Динамические ключи ассетов допустимы: `self:GetAsset("Animations/Punch" .. self.PunchCount)`. `BaseSpec` задаёт фолбэк ассетов для общих скиллов.
- Верхние привязки объявляйте через `const`; `--!native` / `--!optimize 2` — только для по-настоящему горячего серверного кода.
- Для нового кода предпочитайте `function Skill.onInit(self)`; при редактировании следуйте стилю файла.

## Проверка

- Кулдаун и прерывание работают при стане/рэгдолле; каждый бинд — hold-to-cast, поля `Hold` не существует.
- Нет повторных попаданий по одной цели на повторяющихся кадрах (`AlreadyHit`).
- Все эффекты и параметры освобождаются при прерывании; все пути `GetAsset` разрешаются для каждого скина спека.
- Автоматического test runner нет. Отформатируйте код: `lune run tools/format.luau --fix --src`; осмотрите контекст `lune run tools/context.luau` и влияние `lune run tools/impact.luau <target>`; проверьте в Studio.

Связанные: [[Combat pipeline (RU)]], [[Sequencer (RU)]], [[Attack hooks (RU)]], [[VFX replication (RU)]]. Оригинал: [[Create a combat skill]].
