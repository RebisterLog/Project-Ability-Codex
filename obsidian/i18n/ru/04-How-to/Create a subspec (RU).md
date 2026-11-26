# Создание сабспека

Сабспек — дополнительный слот спека, наложенный на основной. Он использует тот же механизм, что [[Create a spec (RU)]], но находится в слоте `SubSpec`.

## Чек-лист

1. Создайте `src/server/specs/<Name>.luau` с той же формой `Skills` / `onInit`, что и у основного спека.
2. Создайте скин в `src/shared/configs/Skins/<Name>/` (как минимум `None`).
3. Добавьте запись в `src/shared/configs/Specs.luau` с `Type = "SubSpec"` — это единственный источник истины для слота (`SpecService:GetSpecType` записывает `SpecData.Slot`); отдельного поля слота в модуле спека нет. `Character.SetSpec` затем вызывает `created:Init({ Movement = slot == "Spec" })`, поэтому основной спек владеет анимациями движения тела, а сабспек — нет.
4. Добавьте обязательный бинд для каждого скилла: без него скилл предупреждает и пропускается. Конфликтующие бинды разрешаются по слоту: `Spec` раньше `SubSpec`, затем по алфавиту id; клавишу получает первый применимый скилл. Все бинды hold-to-cast, поля `Hold` нет. См. [[Input and BindService (RU)]].
5. Добавьте ассеты в `ReplicatedStorage.assets.<Name>.<Skin>`.

## Правила наложения

- Переопределяйте только реально отличающиеся скиллы. Общие остаются `~/skills/...`.
- Сабспек скилл с тем же id, что и у спека, конкурирует за бинд; приоритет у слота `Spec`.
- Порядок инициализации: `Character.SetSpec` (`Character/init.luau:187-220`) вызывает `SpecService:CreateSpec` (`:74-120`), затем `created:Init({ Movement = slot == "Spec" })` (`:217`). `CreateSpec` сам `Init` не вызывает.
- `Spec.Init` (`Spec.luau:37-63`) ставит атрибуты `Idle/Run/Walk/Jump/FreeFall` с фолбэком на `ConfigService:Get("DefaultAnimations").Movement`, уважает `options.Movement`, затем вызывает `Data.onInit`. `Skill.Init` (`Skill.luau:172-192`) вызывает `onInit` каждого скилла.
- Разрешение ассетов проходит через базовый спек (`BaseSpec`) и скин `None`, поэтому необязательные записи имеют фолбэк. `None` — имя скина по умолчанию, а не фолбэк для каждого пути. Используйте `GetAsset` / `TryGetAsset` единообразно.

## Проверка

- Экипируйте оба слота и убедитесь, что приоритет биндов соответствует таблице выше.
- Убедитесь, что `onInit` обоих спеков выполняется и модели привариваются один раз; сабспек не перезаписывает анимации движения тела.
- Отформатируйте код: `lune run tools/format.luau --fix --src`, проверьте `lune run tools/context.luau` и `lune run tools/impact.luau <target>`. Test runner нет — проверяйте в Studio.

Связанные: [[Spec and SubSpec (RU)]], [[Create a spec (RU)]], [[Skill contract and lifecycle (RU)]]. Оригинал: [[Create a subspec]].
