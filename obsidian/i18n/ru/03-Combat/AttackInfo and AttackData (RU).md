# AttackInfo и AttackData

`AttackInfo` описывает атаку до её разрешения. `AttackData` — результат, возвращаемый `CombatService:Attack(...)` как Promise.

## Поля AttackInfo (все необязательны)

| Поле | Содержимое |
|---|---|
| `Priority` | Приоритет/порядок атаки. |
| `Damage` | Величина урона. |
| `Block` | `Blockable`, `PerfectBlockable`, `BlockBreak`, `BlockCancel`, `BlockIgnore`. |
| `Stun` | `Duration`, `Priority` (`Enums.Stun`). |
| `Knockback` | `Preset`, `Direction { Mode, Point/Vector, Add }`, `Push`, `Lift`, `Hold`, `Stiffness`, `MaxForce`. См. [[Knockback and movement (RU)]]. |
| `Angular` | `Velocity`, `Speed`, `Duration`, `MaxTorque`. |
| `Ragdoll` | `Duration`. |

## Значения перечислений

```
IFrames: Ragdoll=10, Dodge=15, Grab=50, True=10000
Stun:    None=0, Light=10, Medium=20, Heavy=30
```

## AttackData.State

| Флаг | Значение |
|---|---|
| `Success` | Попадание зафиксировано: не промах, не i-frame, не мёртвая цель. |
| `Continue` | Разрешено продолжение / комбо. |
| `Blocking` | Цель удерживала блок. |
| `Blocked` | Удар попал в блок. |
| `BlockBroken` | Блок сломан этим ударом. |
| `BlockCanceled` | Блок полностью отменён. |
| `PerfectBlocking` | Цель была в окне идеального блока. |
| `PerfectBlocked` | Атакующий наказан идеальным блоком. |
| `BlockIgnored` | Атака игнорировала блок (например, захват). |
| `IFrames` | Уровень i-frames цели (число). |
| `Armored` | У цели была супер-броня. |

## Примеры исходов

```
обычный удар:    Success, Continue
обычный блок:    Success, Continue, Blocking, Blocked
слом блока:      Success, Continue, Blocking, Blocked, BlockBroken
идеальный блок:  Success, Blocking, Blocked, PerfectBlocking, PerfectBlocked, без Continue
отмена блока:    Success, Continue, Blocking, BlockCanceled
```

Связанные: [[Attack hooks (RU)]], [[Hitbox and targeting (RU)]], [[Character parameters (RU)]], [[Knockback and movement (RU)]]. Оригинал: [[AttackInfo and AttackData]].
