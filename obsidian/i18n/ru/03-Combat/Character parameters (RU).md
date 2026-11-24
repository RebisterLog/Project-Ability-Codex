# Параметры персонажа

Параметры — многослойные временные модификаторы компонента персонажа. Несколько источников могут добавить один и тот же параметр; последний слой имеет приоритет и удаляется при очистке владельца.

```luau
local mod = character:AddParameter("MaxWalkSpeed", 3)
local current = character:GetParameter("MaxWalkSpeed")
mod:Destroy() -- освободить слой
```

| Параметр | Эффект |
|---|---|
| `MaxWalkSpeed` | Ограничение скорости движения. |
| `MinWalkSpeed` | Минимальная скорость (используется `Run`). |
| `MaxJumpPower` | Ограничение силы прыжка. |
| `IFrames` | Уровень неуязвимости (`Enums.IFrames`). |
| `Stun` | `{ Duration, Priority }` (`Enums.Stun`). |
| `Armor` | Супер-броня; см. [[AttackInfo and AttackData (RU)]]. |
| `Timescale` | Множитель анимации/скорости; используется `seq.Speed`. |
| `Ragdoll` | Принудительное состояние рэгдолла. |
| `Restrain` | Отключение движения. |
| `NoCollision` | Отключение коллизий персонажа. |

## Владение

Добавляйте параметры в `onInit` или в кадре секвенса, затем регистрируйте возвращённый объект в `self.Janitor` или `seq.Cleaner`. При прерывании [[Sequencer (RU)]] cleaner освобождает все слои, и движение автоматически возвращается к предыдущему состоянию.

Связанные: [[Skill contract and lifecycle (RU)]], [[Knockback and movement (RU)]], [[Bot combat AI (RU)]]. Оригинал: [[Character parameters]].
