# Spec и SubSpec

**Spec** — загрузка персонажа: список скиллов, бинды, скин (анимации, звуки, модели, статы) и логика инициализации. У персонажа может быть основной спек (`Spec`) и дополнительный слот (`SubSpec`), наложенный поверх.

## Четыре части спека

| Часть | Путь |
|---|---|
| Модуль спека | `src/server/specs/<Name>.luau` |
| Конфиг скина | `src/shared/configs/Skins/<Name>/None.luau` (и другие папки скинов) |
| Публичный конфиг | `src/shared/configs/Specs.luau` (`DisplayName`, `IsPublic`, `Binds`) |
| Ассеты | `ReplicatedStorage.assets.<Name>.<Skin>` с `Animations`, `Sounds`, `Models`, `VFXs`, `Stand` (`Music/` не используется) |

## Метаданные для UI

Публичный конфиг также хранит данные для отображения: `Rarity` (код из `src/shared/configs/Rarity.luau`), `InventoryIcon` и `HudIcon` (id ассетов, необязательные) и `Description` (строка Roblox RichText). Оба конфига лежат в `src/shared`, поэтому клиент требует их напрямую — через Proxy ничего не реплицируется. `Rarity` сопоставляет код с `{ Name, Color, Order }` и автоматически загружается `ConfigsService`.

Экипировка идёт через пакеты `SetSpecSlot { Slot, SpecName? }` и `SetSkin { SpecName, SkinName? }`. Сервер проверяет владение по имени через `SpecModule:GetSpecIdByName`, валидирует слот и запрещает очищать основной слот `Spec` — пустое состояние это спек `Standless`. Снятие `SubSpec` вызывает `SpecModule:ClearSlot("SubSpec")`, снятие скина — `SkinModule:EquipSkin(name, "None")`.

Удаление идёт через `DeleteItem { Kind, Id }`, где `Kind` — `"Spec"` или `"Skin"`, а `Id` — uuid записи во владении. Сервер сначала снимает предмет: `SpecModule:DeleteSpec` ставит `Standless` в основной слот или очищает `SubSpec`, затем удаляет запись вместе с `EquippedSkins` и `SpecBinds`. `SkinModule:DeleteSkin` сначала сбрасывает скин на `"None"`. Сам `Standless` удалить нельзя.

## Правила путей скиллов

| Префикс | Значение | Пример |
|---|---|---|
| `~/skills/` | Общий скилл, доступный любому спеке | `"~/skills/Punch"` |
| `@Specs/<Name>/` | Уникальный скилл персонажа | `"@Specs/Undyne/ArcSpearStrike"` |

Значения справа — лишь соглашение об именах: `SkillService:CreateSkill` ищет модуль по имени, поэтому ключ обязан равняться имени файла скилла.

## Слоты и бинды

- Слот задаётся полем `Type = "SubSpec"` в `Specs.luau` (единственный источник истины; по умолчанию `"Spec"`), а в `SpecData.Slot` он только записывается.
- При конфликте биндов кандидаты сортируются по слоту (`Spec` раньше `SubSpec`), затем по алфавиту id скилла. Клавишу получает первый кандидат, который реально может применить скилл сейчас; если никто не может, её удерживает кандидат с наивысшим приоритетом до отпускания.
- Бинд обязателен для каждого скилла: без него скилл пропускается с предупреждением `No bind for skill ...`. Все бинды hold-to-cast, опции `Hold` не существует. См. [[Input and BindService (RU)]].

## Порядок сборки

`Character.SetSpec` (`Character/init.luau:187-220`) → `SpecService:CreateSpec` (`:74-120`: конфиг + скин, `SkillService:CreateSkill`, `spec:AddSkill`, бинды) → `created:Init({ Movement = slot == "Spec" })` (`:217`) → `Spec.Init` (`Spec.luau:37-63`: анимации движения с фолбэком на `ConfigService:Get("DefaultAnimations").Movement`, затем `Data.onInit`) → `Skill.Init` (`Skill.luau:172-192`: `onInit` скилла). `CreateSpec` сам `Init` не вызывает; `Spec:AddSkill` вызывает `skill:Init()`. Сабспек поэтому не владеет анимациями движения тела.

## Разрешение ассетов

Скиллы читают ассеты через `self:GetAsset("Animations/Block")` относительно `Spec.Data.Assets` (слитого скина), с фолбэком через `BaseSpec` в `SpecService:GetSpecData`. `None` — просто имя скина по умолчанию, а не фолбэк для каждого пути: `GetAsset` предупреждает и прерывает каст, если ассет не найден, `TryGetAsset` молча возвращает `nil`. Дополнительные скины рекурсивно сливаются в `None` (`Skins/init.luau`); нестандартные скины выдаются через `addSkin` и экипируются через `changeSkin`.

Связанные: [[Create a spec (RU)]], [[Create a subspec (RU)]], [[Skill contract and lifecycle (RU)]], [[Player and character lifecycle (RU)]]. Оригинал: [[Spec and SubSpec]].
