# Sequencer

`Sequencer` drives frame-based animations for most combat skills. A sequence is created through `CombatService.CreateSequence(character, data)` and owned by the skill's `Janitor`.

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
        {15, function(seq) -- hitbox + attack end, 20}, -- loop frames 15-20
        {45}, -- end frame
    },
}))

self.Sequence:Play()
self.Sequence:Await()
self.Sequence:Stop()
self.Sequence:AdjustSpeed(multiplier)
self.Sequence.CurrentFrame
```

## Frame entries

- `{ frame, callback }` — run once at `frame`.
- `{ frame, callback, loopEndFrame }` — loop from `frame` to `loopEndFrame`.
- `{ frame }` — end marker without work.

`Validate` can abort a sequence when its condition stops holding (for example a grab target disappeared).

## Scoped cleanup

| Method | Meaning |
|---|---|
| `seq.Cleaner:Add(obj)` | Destroyed when the sequence stops or ends. |
| `seq.Cleaner:Set(key, obj)` | Keyed version; replaces the previous object. |
| `seq.Cleaner:Remove(key)` | Release early. |

`seq.Speed` follows the character's `Timescale` parameter, so animation and hit timing stay aligned.

Related: [[Combat pipeline]], [[Skill contract and lifecycle]], [[Character parameters]], [[VFX replication]].
