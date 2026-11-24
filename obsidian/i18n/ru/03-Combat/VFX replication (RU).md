# Репликация VFX

`VFXService` запускает и останавливает эффекты для выбранного списка игроков. Эффекты реализованы в `src/shared/effects/` и запускаются серверным кодом во время секвенса или атаки.

```luau
VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, {
    Animation = anim, Speed = seq.Speed,
})
VFXService:StartEffect(Players:GetPlayers(), "Sound", rootPart, sound)
VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", {
    UUID = self.UUID, Particle = particle, Origin = rootPart,
})
VFXService:StartEffect(Players:GetPlayers(), "Highlight", instance, {
    FillColor = Color3.new(1, 0, 0), Lifetime = 1, Tween = true,
})
VFXService:StopEffect(Players:GetPlayers(), "Animation", character.instance, { Animation = anim })
```

| Тип | Аргумент цели |
|---|---|
| `Animation` | Инстанс персонажа и payload анимации. |
| `Sound` | Источник звука и payload. |
| `EmitParticle` | payload с `UUID`, `Particle`, `Origin`. |
| `Highlight` | Инстанс и payload подсветки. |
| `Hitbox`, `Ragdoll` | Используются хуками и отладочными видами. |

## Правила

1. Каждый запущенный эффект должен быть остановлен: зарегистрируйте остановку в `seq.Cleaner` или `Janitor` скилла.
2. Ассеты приходят из скина спека через `self:GetAsset(...)`; см. [[Spec and SubSpec (RU)]].
3. Список игроков определяет, кто видит эффект; список выбирает сервер.
4. Прерванный скилл останавливает эффекты в `Interrupt`. См. [[Skill contract and lifecycle (RU)]].

Связанные: [[Sequencer (RU)]], [[Combat pipeline (RU)]], [[Attack hooks (RU)]]. Оригинал: [[VFX replication]].
