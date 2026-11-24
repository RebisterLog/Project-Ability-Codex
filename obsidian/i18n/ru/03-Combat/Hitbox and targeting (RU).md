# Хитбокс и выбор цели

`CombatService:Hitbox` — серверный пространственный запрос, возвращающий кандидатов-компоненты `Character`.

```luau
local targets = CombatService:Hitbox({
    Skill = self,             -- необязательно; вызывает Casted
    Caster = character,       -- обязательно
    Info = {
        Size = Vector3.new(7, 7, 7), -- Vector3 => коробка, number => радиус сферы
        Offset = CFrame.new(0, 0, -3),
        Origin = CFrame.new(),  -- необязательная переопределённая точка
        SortByDistance = true,
        CanQueryCaster = false,
        Parameters = OverlapParams.new(),
        Debug = false,
    },
})
```

| Поле | Поведение |
|---|---|
| `Size` | `Vector3` использует `GetPartBoundsInBox`; `number` — `GetPartBoundsInRadius`. |
| `Offset` | Применяется от `RootPart` кастера. |
| `Origin` | Заменяет точку отсчёта по умолчанию. |
| `SortByDistance` | Ближайшие цели первыми. |
| `CanQueryCaster` | Разрешить возврат самого кастера. |
| `Parameters` | Пользовательский `OverlapParams`. |
| `MovementCorrection` | Перенести начало запроса в компенсированную по задержке клиентскую позу кастера (не более 3 стадсов, только горизонталь); при отсутствии сэмпла или для ботов — эвристика по скорости с лимитом 2 стадса. Игнорируется при явном `Origin`. См. [[Lag compensation (RU)]]. |
| `Debug` | Визуализация запроса через VFX. |

## Типичный паттерн

Кадры цикла вызывают хитбокс, пропускают цели уже в `self.AlreadyHit`, вызывают `CombatService:Attack` и добавляют цель в `AlreadyHit` только при `Data.State.Success`. Это предотвращает многократные попадания по одной цели за циклический секвенс.

Клиентский `TargetLockService` отвечает за выбор и отображение цели, но не решает попадания. См. [[Runtime boundaries (RU)]].

Связанные: [[Sequencer (RU)]], [[AttackInfo and AttackData (RU)]], [[Character parameters (RU)]], [[Lag compensation (RU)]]. Оригинал: [[Hitbox and targeting]].
