# Sequencer

`Sequencer` управляет покадровыми анимациями большинства боевых скиллов. Секвенс создаётся через `CombatService.CreateSequence(character, data)` и принадлежит `Janitor` скилла.

```luau
self.Sequence = self.Janitor:Add(CombatService.CreateSequence(character, {
    Validate = function() return true end,
    Frames = {
        {0, function(seq)
            seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 3))
            VFXService:StartEffect(Players:GetPlayers(), "Animation", character.instance, {
                Animation = anim, Speed = seq.Speed,
            })
            seq.Cleaner:Add(function()
                VFXService:StopEffect(Players:GetPlayers(), "Animation", character.instance, { Animation = anim })
            end)
        end},
        {15, function(seq) -- хитбокс + атака end, 20}, -- цикл кадров 15-20
        {45}, -- конечный кадр
    },
}))

self.Sequence:Play()
self.Sequence:Await()
self.Sequence:Stop()
self.Sequence:AdjustSpeed(multiplier)
self.Sequence.CurrentFrame
```

## Записи кадров

- `{ frame, callback }` — выполнить один раз на кадре `frame`.
- `{ frame, callback, loopEndFrame }` — цикл от `frame` до `loopEndFrame`.
- `{ frame }` — конечная метка без действий.

`Validate` может прервать секвенс, если условие перестало выполняться (например, исчезла цель захвата).

## Локальная очистка

| Метод | Значение |
|---|---|
| `seq.Cleaner:Add(obj)` | Удаляется при остановке или завершении секвенса. |
| `seq.Cleaner:Set(key, obj)` | По ключу; заменяет предыдущий объект. |
| `seq.Cleaner:Remove(key)` | Освободить досрочно. |

`seq.Speed` следует параметру `Timescale` персонажа, поэтому анимация и тайминг попаданий остаются синхронными.

Связанные: [[Combat pipeline (RU)]], [[Skill contract and lifecycle (RU)]], [[Character parameters (RU)]], [[VFX replication (RU)]]. Оригинал: [[Sequencer]].
