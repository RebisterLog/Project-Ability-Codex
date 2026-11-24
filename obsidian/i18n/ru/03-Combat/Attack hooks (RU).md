# Хуки атаки

Каждая атака проходит через трёхфазный конвейер хуков до получения финального результата.

```luau
self.AttackHook = Hook.new("Attack", { "Precast", "Cast", "Postcast" })
self.AttackHook:Hook("Precast", "MyHook", priority, function(Data)
    return true -- false / nil прерывает конвейер
end)
```

| Фаза | Назначение |
|---|---|
| `Precast` | До эффектов: проверки и сигнал `Attacked`. |
| `Cast` | Применение эффектов попадания: урон, стан, нокабк. |
| `Postcast` | Финализация и возврат результата. |

Хук получает `AttackData` и **должен вернуть `true`**, чтобы обработка продолжалась. Меньший приоритет выполняется позже; порядок важен, если один хук меняет состояние, которое читает другой.

## Существующие хуки

`Angular`, `Armor`, `Bleed`, `Block`, `Burn`, `Damage`, `HitFeedback`, `IFrames`, `Knockback`, `NPCOwnership`, `Ragdoll`, `Restand`, `Stun`. Они лежат в `src/server/services/CombatService/Hooks/` и загружаются автоматически.

## Сигналы

- `Casted` — вызывается `CombatService:Hitbox`, если передан скилл.
- `Attacked` — вызывается в конвейере; используется логикой блока и обратной связи.
- `Interrupted` — скиллы с `Interrupt` подписываются на него.

Связанные: [[Create a hook (RU)]], [[AttackInfo and AttackData (RU)]], [[Combat pipeline (RU)]], [[Bot combat AI (RU)]]. Оригинал: [[Attack hooks]].
