# Ввод и BindService

Бинды лежат в `src/shared/configs/Specs.luau` в таблице `Binds` каждого спека. Бинд сопоставляет id скилла с `Enum.KeyCode` или `Enum.UserInputType` (кнопки мыши и тач поддерживаются).

## Как ввод доходит до скилла

```
клавиша / мышь / тач
  -> клиентский BindService
  -> пакет StartSkill({ Id, AimPoint? })
  -> серверный SkillService проверяет
  -> spec:ActivateSkill(skillId, aimPoint)
  -> Skill:Activate(aimPoint)
```

## AimPoint (положение курсора в мире)

`StartSkill` — это структура, а не голая строка: `{ Id: string, AimPoint: Vector3? }`. Точку шлют только id из списка `AIMED_SKILLS` в `BindService`; остальные бинды шлют `nil`, поэтому бюджет клиент→сервер для существующих скиллов не меняется.

- **Обычная камера:** берётся `Mouse.Hit.Position`, ограниченная `MAX_AIM_DISTANCE` (120 стадов) от `HumanoidRootPart` персонажа.
- **ShiftLock:** когда `TargetLockService.Locked == true` или `UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter`, курсор закреплён в центре и `Mouse.Hit` бессмыслен. Клиент шлёт `root.Position + root.CFrame.LookVector * MAX_AIM_DISTANCE` — самую дальнюю точку по направлению взгляда персонажа.
- **Нет персонажа / нет `Mouse.Hit`:** используется тот же запасной вариант по LookVector.

Сервер не доверяет точке для определения попаданий: это только подсказка направления для запуска снаряда. `SkillService:ActivateSkill(character, skillId, aimPoint)` передаёт её через `Spec:ActivateSkill` в `Skill:Activate(aimPoint)` и дальше в `SkillData.Activate(self, aimPoint)`. Скиллы, которым прицел не нужен, просто игнорируют лишний аргумент.

## Важные моменты

- **Опции Hold нет.** Пока клавиша нажата, бинд запрашивается повторно, и сервер проверяет каждый запрос. Общий бюджет — примерно 12 пакетов/сек на все удерживаемые клавиши. После отпускания `StopSkill` повторяется короткое время, чтобы потерянный пакет не оставил скилл застрявшим.
- **Скиллы-переключатели исключены из повтора:** `Run` через клиентский флаг `Toggle`; `Summon` через явный список `NON_REPEATABLE` в `BindService`.
- **Конфликт биндов:** кандидаты сортируются по слоту (`Spec` перед `SubSpec`), затем по алфавиту id. Первый кандидат, который может быть применён сейчас, получает клавишу. Кандидат, заблокированный кулдауном, отключённым состоянием, отсутствующим скиллом или состоянием персонажа, передаёт клавишу следующему. Если никто не может стартовать, клавишу удерживает самый приоритетный кандидат до отпускания.
- Проверка на сервере авторитетна: кулдаун, стан, рэгдолл и состояние жизни проверяются до `Activate`. См. [[Combat pipeline (RU)]].

## Типичная таблица биндов

```luau
Binds = {
    ["Punch"] = Enum.UserInputType.MouseButton1,
    ["Block"] = Enum.KeyCode.F,
    ["Dash"]  = Enum.KeyCode.C,
    ["Run"]   = Enum.KeyCode.LeftControl,
    ["Grab"]  = Enum.KeyCode.X,
}
```

Связанные: [[Spec and SubSpec (RU)]], [[Create a spec (RU)]], [[Data schemas and Proxy (RU)]]. Оригинал: [[Input and BindService]].
