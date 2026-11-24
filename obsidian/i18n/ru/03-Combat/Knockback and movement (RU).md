# Нокабк и движение

Конфигурация нокабка лежит в `src/shared/combat/Knockback.luau` и встраивается в `AttackInfo.Knockback`.

| Поле | Значение |
|---|---|
| `Preset` | Именованный shorthand для combinations `Push`, `Lift`, `Hold` (например, `"Launch"`). |
| `Direction.Mode` | `AwayFromAttacker`, `TowardsAttacker`, `FromPoint`, `Custom`. |
| `Direction.Point` / `Vector` / `Add` | Входы для неотносительных режимов и дополнительное смещение. |
| `Push` | Горизонтальных стадов/сек вдоль `Direction`. |
| `Lift` | Вертикальных стадов/сек. |
| `Hold` | Время жизни мовера в секундах — **не** демпфирование. |
| `Stiffness` | Жёсткость пружины мовера. |
| `MaxForce` | `"Auto"` (по умолчанию) разблокирует ось Y только при ненулевом `Lift`. |

## Параметры движения

`MaxWalkSpeed`, `MinWalkSpeed` и `MaxJumpPower` — многослойные [[Character parameters (RU)]]. Скиллы обычно снижают `MaxWalkSpeed` во время секвенса и освобождают его через `seq.Cleaner`.

## Угловое движение

`AttackInfo.Angular` содержит `Velocity`, `Speed`, `Duration`, `MaxTorque`; хук `Angular` применяет его вместе с нокабком.

## Практическое правило

Сначала настраивайте `Push`/`Lift`/`Hold`, затем рассматривайте `Preset` для повторного использования. Изменение только клиентской анимации не изменит реальное положение персонажа.

Связанные: [[AttackInfo and AttackData (RU)]], [[Attack hooks (RU)]], [[Character parameters (RU)]]. Оригинал: [[Knockback and movement]].
