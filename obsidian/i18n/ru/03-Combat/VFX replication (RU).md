# Репликация VFX

`VFXService` запускает и останавливает эффекты для выбранного списка игроков. Эффекты реализованы в `src/shared/effects/` и запускаются серверным кодом во время секвенса или атаки.

`StartEffect` / `StopEffect` принимают **ровно три аргумента**: `(players, name, dataTable)`. `players` — список объектов `Player` или `Model` (модель превращается в игрока через `Players:GetPlayerFromCharacter`); `data` — протокольная таблица самого эффекта.

```luau
const clip = self:GetAsset("Animations/NAME") -- таблица клипа: .Animation, .Priority, .Looped

-- старт анимации: Animation = таблица клипа
VFXService:StartEffect(Players:GetPlayers(), "Animation", {
    Character = character.instance, Animation = clip, Speed = seq.Speed,
})
VFXService:StartEffect(Players:GetPlayers(), "Sound", {
    Origin = character.RootPart, Sound = self:GetAsset("Sounds/NAME"), Volume = 1,
})
VFXService:StartEffect(Players:GetPlayers(), "EmitParticle", {
    UUID = self.UUID, Particle = particle, Origin = character.RootPart,
})
VFXService:StartEffect(Players:GetPlayers(), "Highlight", {
    Character = target.instance, FillColor = Color3.fromRGB(255, 0, 0), Lifetime = 1, Tween = true,
})
-- стоп анимации: Animation = сырой инстанс Animation
VFXService:StopEffect(Players:GetPlayers(), "Animation", {
    Character = character.instance, Animation = clip.Animation, FadeTime = 0.1,
})

VFXService:StartEffectExcept(players, name, data) -- всем, кроме players
VFXService:StopEffectExcept(players, name, data)
```

Обратите внимание на асимметрию: старт берёт таблицу клипа, стоп — `clip.Animation`.

| Тип | Поля `data` |
|---|---|
| `Animation` | `Character` (Model), `Animation` (таблица клипа при старте / `clip.Animation` при стопе), `Speed`, `FadeTime`. |
| `Sound` | `Origin`, `Sound`, `Volume`, `MaxDistance`, `MinDistance`. |
| `EmitParticle` | `UUID`, `Particle`, `Origin`, `Offset`, `UseForge`. |
| `Highlight` | `Character` / `Adornee` / `UUID`, `FillColor`, `OutlineColor`, `Lifetime`, `Tween`. |
| `Barrage`, `EquipShell`, `CameraShake`, `Hitbox` и др. | См. модуль эффекта в `src/shared/effects/`. |
## Правила

1. Каждый запущенный эффект должен быть остановлен: зарегистрируйте остановку один раз в `seq.Cleaner` на кадре 0 (сработает и при естественном завершении, и при прерывании) или в `self.Cleaner` скилла. `Janitor` у скилла нет.
2. Ассеты приходят из скина спека через `self:GetAsset(...)`; см. [[Spec and SubSpec (RU)]].
3. Список игроков определяет, кто видит эффект; список выбирает сервер. Чтобы показать эффект всем, кроме некоторых игроков (например, скрыть от кастера), используйте `StartEffectExcept` / `StopEffectExcept`.
4. Прерванный скилл останавливает эффекты через зарегистрированную очистку. См. [[Skill contract and lifecycle (RU)]].

Связанные: [[Sequencer (RU)]], [[Combat pipeline (RU)]], [[Attack hooks (RU)]]. Оригинал: [[VFX replication]].
