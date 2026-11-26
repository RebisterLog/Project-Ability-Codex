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
        MovementCorrection = true, -- компенсация задержки для ближнего боя
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
| `MovementCorrection` | Перенести начало запроса в предсказанную клиентскую позу кастера из `ClientStateService:GetMetadata(Caster).Predicted`; если сэмпла нет — эвристика по скорости с лимитом `MOVEMENT_CORRECTION_LIMIT = 2`. Игнорируется при явном `Origin`. Используется в `Punch.luau`. См. [[Lag compensation (RU)]]. |
| `Debug` | Визуализация запроса через VFX. |

## Типичный паттерн

Повторяющиеся кадры (задаются ключами `Interval = N` / `Offset = M`, а не циклом) вызывают хитбокс, пропускают цели уже в `self.AlreadyHit`, вызывают `CombatService:Attack` и добавляют цель в `AlreadyHit` только при `Data.State.Success`. Это предотвращает многократные попадания по одной цели за секвенс. Если скилл можно применить дважды, очистите `self.AlreadyHit` на кадре 0.

Клиентский `TargetLockService` отвечает за выбор и отображение цели, но не решает попадания. См. [[Runtime boundaries (RU)]].

Связанные: [[Sequencer (RU)]], [[AttackInfo and AttackData (RU)]], [[Character parameters (RU)]], [[Lag compensation (RU)]]. Оригинал: [[Hitbox and targeting]].
