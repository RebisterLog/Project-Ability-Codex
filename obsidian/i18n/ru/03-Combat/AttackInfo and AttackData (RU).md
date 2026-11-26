# AttackInfo и AttackData

`AttackInfo` описывает атаку до её разрешения. `AttackData` — результат, возвращаемый `CombatService:Attack(...)` как Promise; `Info` клонируется и глубоко замораживается, оригинал остаётся в `OriginalInfo`.

## Поля AttackInfo (все необязательны)

| Поле | Содержимое |
|---|---|
| `Priority` | Приоритет/порядок атаки. |
| `Hitbox` | Приватное соглашение скилла (не часть типа), см. [[Hitbox and targeting (RU)]]. |
| `Damage` | Величина урона. |
| `Restand`, `Bleed`, `Burn` | Дополнительные эффекты. |
| `Block` | Все флаги — обязательные boolean: `Blockable`, `PerfectBlockable`, `BlockBreak`, `BlockCancel`, `BlockIgnore`. |
| `Stun` | `Duration`, `Priority` (`Enums.Stun`). |
| `Knockback` | `Preset`, `Direction { Mode, Point/Vector, Add }`, `Push`, `Lift`, `Hold`, `Stiffness`, `MaxForce`. См. [[Knockback and movement (RU)]]. |
| `Angular` | `Velocity`, `Speed`, `Duration`, `MaxTorque`. |
| `Ragdoll` | `Duration`. |
| `HitEffects`, `HitSounds`, `HitAnimations` | Реакции попадания. |

`BlockIgnore` доминирует, `BlockBreak` не зависит от `Blockable`. Есть важное исключение: перфектный блок против `PerfectBlockable = true` разрешается раньше (`Block.luau:89-96`), даёт `PerfectBlocked`/`Absorbed` и полностью отменяет `BlockBreak` — поэтому финишер, который должен ломать стойку, обязан ставить `PerfectBlockable = false`. Заблокированный удар даёт состояние `Absorbed`: из применённого хита убираются Damage, Ragdoll, Restand, Stun, Bleed, HitEffects, Knockback и Angular.

Чтобы перфектный блок парировал, а обычный блок пропускал удар, используйте `Blockable = false, PerfectBlockable = true, BlockIgnore = false`. `BlockResolver` поглотит только перфектную ветку; при обычном блоке не выставятся ни `Blocked`, ни `Absorbed`, и хит дойдёт до цели. Не переписывайте это в скилле через `victim.Block.PerfectBlockTime`/`os.clock()` — резолвер уже работает с авторитетным состоянием цели.

`HitEffects` — это **массив таблиц** (`{ { Particle = ..., Sound = ... } }`), а не Folder. Строковые значения, кроме `"Default"`, разрешаются через `skill:TryGetAsset(...)`, поэтому атаке, использующей ключи из скина, нужно передавать `Skill = self` в `CombatService:Attack`.

## Значения перечислений

```
IFrames: Ragdoll=10, Dodge=15, Grab=50, True=10000
Stun:    None=0, Light=10, Medium=20, Heavy=30
Knockback presets: Tap, Shove, Slam, Launch; Direction.Add: ToFront / Custom
```
Также доступны `Enums.StunTime`, `Enums.StunSpeed`, `Enums.Ragdoll`, `Enums.CastSpeed` — для ограничения скорости каста используйте `Enums.CastSpeed.Medium`, а не число. `Hold` в knockback — время жизни mover'а, а не демпфирование.

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
| `Absorbed` | Удар поглощён блоком: урон и сопутствующие эффекты сняты. |
| `Ragdolled` | Не типизированное состояние, см. хуки. |

В рантайме `State` может нести `Ragdolled` и `Absorbed` помимо объявленных выше флагов.

`AttackData` также несёт `OriginalInfo`, `DamageDealt`, `NoDeathDeferred`.

## Примеры исходов

```
обычный удар:    Success, Continue
обычный блок:    Success, Continue, Blocking, Blocked, Absorbed
слом блока:      Success, Continue, Blocking, Blocked, BlockBroken
идеальный блок:  Success, Blocking, Blocked, PerfectBlocking, PerfectBlocked, без Continue
отмена блока:    Success, Continue, Blocking, BlockCanceled
игнор блока:     BlockIgnored
```

Связанные: [[Attack hooks (RU)]], [[Hitbox and targeting (RU)]], [[Character parameters (RU)]], [[Knockback and movement (RU)]]. Оригинал: [[AttackInfo and AttackData]].
