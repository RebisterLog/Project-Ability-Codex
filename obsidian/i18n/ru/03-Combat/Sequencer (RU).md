# Sequencer

`Sequencer` управляет покадровыми анимациями большинства боевых скиллов. Секвенс создаётся через `CombatService.CreateSequence(character, data)` и добавляется в `self.Cleaner` скилла (`Crane.Buttler`), а не в `self.Janitor`.

```luau
self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
    Validator = function() return true end,
    Frames = {
        {0, function(seq)
            seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 3))
            const clip = self:GetAsset("Animations/NAME")
            VFXService:StartEffect(Players:GetPlayers(), "Animation", {
                Character = character.instance, Animation = clip, Speed = seq.Speed,
            })
            seq.Cleaner:Add(function()
                VFXService:StopEffect(Players:GetPlayers(), "Animation", {
                    Character = character.instance, Animation = clip.Animation,
                })
            end)
        end},
        {30, function(seq, frame) -- хитбокс + атака
            -- ...
        end, 35, Interval = 4, Offset = 3}, -- повторяющиеся кадры
        {45}, -- конечный кадр
    },
}))

self.Sequence:Play()
self.Sequence:Await()
self.Sequence:Stop()
self.Sequence:AdjustSpeed(multiplier)
self.Sequence.CurrentFrame
self.Sequence:IsPlaying()
self.Sequence:IsPaused()
self.Sequence:Pause()
self.Sequence:Resume()
```

## Записи кадров

- `{ frame, callback }` — выполнить один раз на кадре `frame`.
- `{ frame, callback, endFrame }` — callback на каждом пройденном кадре от `frame` до `endFrame`. Это **не цикл**: указатель просто движется вперёд один раз.
- `{ frame, callback, endFrame, Interval = N, Offset = M }` — срабатывает каждые N кадров, начиная с `frame + M` (по умолчанию `Interval = 1`, `Offset = 0`).
- `{ frame }` — конечная метка без действий.

`Validator` проверяется при создании секвенса и может прервать её, если условие перестало выполняться (например, исчезла цель захвата). Ключ `Validate` игнорируется — не копируйте этот мёртвый паттерн. Устаревший приём `if frame % 4 ~= 0 then return end` заменяйте на `Interval` / `Offset`. Callback получает `(seq, currentFrame)`; валидация кадров происходит один раз при создании.

`CreateSequence` сразу вызывает `AdjustSpeed(character:GetParameter("Timescale"))` (с ограничением 0..10), поэтому любое `data.Speed` перезаписывается. Также он подписывается на параметр и перестраивает активный секвенс, если `Timescale` изменился посреди каста; подписка снимается через `seq.Cleaner`. В скиллах нельзя создавать секвенсы через `Sequencer.new` — это обходит и начальную скорость, и подписку.

## Локальная очистка

| Метод | Значение |
|---|---|
| `seq.Cleaner:Add(obj, method?, label?)` | Удаляется при остановке или завершении секвенса (`Stop()` очищает cleaner). |
| `seq.Cleaner:Set(key, obj, method?)` | По ключу; заменяет предыдущий объект. |
| `seq.Cleaner:Remove(keyOrObject)` | Освободить досрочно. |
| `seq.Cleaner:Has(key)`, `:Clean()`, `:Destroy()` | Проверка, очистка, уничтожение. |

`seq.Cleaner` — `Crane.Buttler`. В него кладут параметры, эффекты и одноразовую очистку; для объектов, которые должны пережить секвенс (например, mover из `Activate`), используйте `self.Cleaner`.

`seq.Speed` следует параметру `Timescale` персонажа (0..10), поэтому анимация и тайминг попаданий остаются синхронными. Перестройка не меняет скорость уже играющих клипов — они остаются со скоростью, с которой были запущены. `Skill:Pause()` / `Skill:Resume()` оборачивают одноимённые методы секвенса.

Связанные: [[Combat pipeline (RU)]], [[Skill contract and lifecycle (RU)]], [[Character parameters (RU)]], [[VFX replication (RU)]]. Оригинал: [[Sequencer]].
