# Параметры персонажа

Параметры — многослойные временные модификаторы компонента персонажа. Несколько источников могут добавить один и тот же параметр; приоритет определяет парсер (`LowestParser` для `MaxWalkSpeed`/`MaxJumpPower`, `HighestParser` для `MinWalkSpeed`/`IFrames`, приоритетный — для `Stun`, `MultParser` для множителей, `ORParser` для boolean, `LastParser` для `CastingSkill`), а не просто «последний победил».

```luau
const mod = character:AddParameter("MaxWalkSpeed", 3) -- { Value, Cleaner, Destroy }
const current = character:GetParameter("MaxWalkSpeed")
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
| `Timescale` | Множитель анимации/скорости; используется `seq.Speed` (0..10). Активные секвенсы следят за параметром и перестраиваются при его изменении посреди каста. |
| `Ragdoll` | Принудительное состояние рэгдолла. |
| `Restrain` | Отключение движения. |
| `NoCollision` | Отключение коллизий персонажа. |
| `CastingSkill` | Активный каст (устанавливается `Skill.Activate` на всё время применения). |
| `CooldownMultiplier`, `DamageMultiplier`, `DamageReceivalMultiplier`, `HealMultiplier` | Множители (используют `MultParser`). |
| `NoRotate`, `Bleeding`, `Burning`, `GodMode`, `Restand`, `NoSkillCast`, `NoDeath`, `DamageHold`, `HamonCharge` | Другие часто используемые флаги и состояние. |

Для ограничения скорости каста используйте `Enums.CastSpeed.Medium`, а не числовой литерал. Другие хелперы: `SetParameterValue`, `RefreshParameter`, `WatchParameter`.

## Владение

Добавляйте параметры в `onInit` или в кадре секвенса, затем регистрируйте возвращённый объект в `self.Cleaner` скилла (`Crane.Buttler`, `Janitor` у скилла нет) или в `seq.Cleaner`. При прерывании [[Sequencer (RU)]] cleaner освобождает все слои, и движение автоматически возвращается к предыдущему состоянию.

Связанные: [[Skill contract and lifecycle (RU)]], [[Knockback and movement (RU)]], [[Bot combat AI (RU)]]. Оригинал: [[Character parameters]].
