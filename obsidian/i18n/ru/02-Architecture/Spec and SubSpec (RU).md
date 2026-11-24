# Spec и SubSpec

**Spec** — загрузка персонажа: список скиллов, бинды, скин (анимации, звуки, модели, статы) и логика инициализации. У персонажа может быть основной спек (`Spec`) и дополнительный слот (`SubSpec`), наложенный поверх.

## Четыре части спека

| Часть | Путь |
|---|---|
| Модуль спека | `src/server/specs/<Name>.luau` |
| Конфиг скина | `src/shared/configs/Skins/<Name>/None.luau` (и другие папки скинов) |
| Публичный конфиг | `src/shared/configs/Specs.luau` (`DisplayName`, `IsPublic`, `Binds`) |
| Ассеты | `ReplicatedStorage.assets.<Name>.<Skin>` с `Animations`, `Sounds`, `Models`, `Music` |

## Правила путей скиллов

| Префикс | Значение | Пример |
|---|---|---|
| `~/skills/` | Общий скилл, доступный любому спеке | `"~/skills/Punch"` |
| `@Specs/<Name>/` | Уникальный скилл персонажа | `"@Specs/Undyne/ArcSpearStrike"` |

## Слоты и бинды

- `SpecSlot` принимает `"Spec"` или `"SubSpec"`.
- При конфликте биндов кандидаты сортируются по слоту (`Spec` раньше `SubSpec`), затем по алфавиту id скилла. Клавишу получает первый кандидат, который реально может применить скилл сейчас; если никто не может, её удерживает кандидат с наивысшим приоритетом до отпускания.
- Опции `Hold` не существует. См. [[Input and BindService (RU)]].

## Порядок сборки

`Character.SetSpec` → `SpecService:CreateSpec` → загрузка конфига и скина → `SkillService:CreateSkill` для каждого скилла → `spec:AddSkill(skill)` → бинды → `Spec.Init` → `Skill.Init`.

## Разрешение ассетов

Скиллы читают ассеты через `self:GetAsset("Animations/Block")` относительно `Spec.Data.Assets`, с фолбэком через базовый спек и скин `None`. `TryGetAsset` используется, когда отсутствие ассета допустимо.

Связанные: [[Create a spec (RU)]], [[Create a subspec (RU)]], [[Skill contract and lifecycle (RU)]], [[Player and character lifecycle (RU)]]. Оригинал: [[Spec and SubSpec]].
