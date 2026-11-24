# Создание боевого скилла

## Чек-лист

1. **Выберите ближайший аналог** из [[Skill contract and lifecycle (RU)]] — не начинайте с жёсткого шаблона.
2. **Комментарий-заголовок**: имя скилла, краткое описание и блок `ASSETS` со всеми анимациями, звуками, моделями и статами, которые использует скилл.
3. **Форма модуля**:
   ```luau
   local Skill: types.SkillData = {
       DisplayName = "<Name>",
       Cooldown = 2,
       SkillCharacters = { "Hit" },
   }
   function Skill:onInit() end
   function Skill:Activate() end
   function Skill:Interrupt() end
   return Skill
   ```
4. **onInit**: получить сервисы через `Crane:GetService`, прочитать ассеты через `self:GetAsset("Animations/...")`, создать секвенс в `self.Janitor`, инициализировать состояние.
5. **Activate**: проиграть секвенс ([[Sequencer (RU)]]) или использовать promise, привязанный к сигналам. На кадрах попадания вызвать [[Hitbox and targeting (RU)]], пропустить уже поражённые цели, вызвать `CombatService:Attack` с [[AttackInfo and AttackData (RU)]].
6. **Interrupt**: остановить секвенс и эффекты, освободить параметры.
7. **Регистрация**: добавить путь в спек (`~/skills/<Name>` или `@Specs/<Spec>/<Name>`) и бинд. См. [[Spec and SubSpec (RU)]], [[Input and BindService (RU)]].

## Соглашения

- Боевая логика остаётся на сервере. См. [[Runtime boundaries (RU)]].
- Используйте `self.Janitor` для ресурсов сервиса и `seq.Cleaner` для ресурсов кадра.
- `SkillCharacters` — свободный список тегов, не перечисление.
- Динамические ключи ассетов допустимы: `self:GetAsset("Animations/Punch" .. self.PunchCount)`.
- Для нового кода предпочитайте двоеточие; при редактировании следуйте стилю файла.

## Проверка

- Кулдаун и прерывание работают при стане/рэгдолле.
- Нет повторных попаданий по одной цели в циклах (`AlreadyHit`).
- Все эффекты и параметры освобождаются при прерывании.
- Отформатируйте код: `lune run tools/format.luau --fix --src`; перед изменением общего модуля проверьте `lune run tools/impact.luau <target>`.

Связанные: [[Combat pipeline (RU)]], [[Sequencer (RU)]], [[Attack hooks (RU)]], [[VFX replication (RU)]]. Оригинал: [[Create a combat skill]].
