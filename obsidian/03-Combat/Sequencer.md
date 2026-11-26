# Sequencer

`Sequencer` drives frame-based animations for most combat skills. A sequence is created through `CombatService.CreateSequence(character, data)` and owned by the skill's `self.Cleaner` (a `Crane.Buttler`).

```luau
self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(character, {
    Validator = function() return self.Target and self.Target.Parent end,
    Frames = {
        {0, function(seq)
            seq.Cleaner:Add(character:AddParameter("MaxWalkSpeed", 3))
            const anim = self:GetAsset("Animations/NAME")
            VFXService:StartEffect(Players:GetPlayers(), "Animation", {
                Character = character.instance, Animation = anim, Speed = seq.Speed,
            })
            seq.Cleaner:Add(function()
                VFXService:StopEffect(Players:GetPlayers(), "Animation", {
                    Character = character.instance, Animation = anim.Animation,
                })
            end)
        end},
        {15, function(seq) --[[ hitbox + attack ]] end, 20}, -- fires on frames 15..20
        {45, function(seq, frame) --[[ repeat hit ]] end, 190, Interval = 4, Offset = 3},
        {205}, -- end marker
    },
}))

self.Sequence:Play()
self.Sequence:Await()
self.Sequence:Stop() -- also cleans seq.Cleaner
self.Sequence:IsPlaying()
self.Sequence:IsPaused()
self.Sequence:Pause()
self.Sequence:Resume()
```

`VFXService` methods take exactly three arguments; there is no positional `RootPart`/animation argument. Note the asymmetry: starting an `Animation` effect takes the clip **table**, stopping takes the raw `clip.Animation`. See [[VFX replication]].

## Frame entries

Positional form `{ startFrame, callback?, endFrame? }` plus optional named keys:

- `{ frame, callback }` — fires once at `frame`.
- `{ frame, callback, endFrame }` — fires on every crossed frame from `frame` to `endFrame`; it is **not** a loop, the playhead moves forward once.
- `{ frame, callback, endFrame, Interval = N, Offset = M }` — repeated hits: fires every `N` frames starting `M` frames past `frame` (defaults 1 and 0). Use this instead of `if frame % N ~= 0 then return end`.
- `{ frame }` — end marker without work.

The callback receives `(seq, currentFrame)`, where `currentFrame` is the exact frame crossed. Frames are validated once at construction: non-empty array, integer start/end with `end >= start`, callback a function, `Interval >= 1`, `Offset >= 0`. The older `{15, fn, 20}` "loopEndFrame" wording is legacy.

The validator key is **`Validator`**. `Validate = function() ... end` is silently ignored (it survives as dead code in some older skills). `Validator` can abort a sequence when its condition stops holding (for example a grab target disappeared).

`CreateSequence` constructs the Sequencer and calls `AdjustSpeed(character:GetParameter("Timescale"))`, so any `data.Speed` is overridden by the character's `Timescale`, clamped to `0..10`.

## Scoped cleanup

`seq.Cleaner` is a `Crane.Buttler`:

| Method | Meaning |
|---|---|
| `seq.Cleaner:Add(obj, method?, label?)` | Destroyed when the sequence stops or ends. |
| `seq.Cleaner:Set(key, obj, method?)` | Keyed version; replaces the previous object. |
| `seq.Cleaner:Remove(key)` | Release early. |

Use `self.Cleaner` for objects that must survive the sequence (e.g. a mover created in `Activate` that does not await). `seq.Speed` follows the character's `Timescale` parameter, so animation and hit timing stay aligned. For hold-to-cast skills, release the sequence on `self.Deactivated:Once(...)` rather than assuming one activation.

Related: [[Combat pipeline]], [[Skill contract and lifecycle]], [[Character parameters]], [[VFX replication]].
