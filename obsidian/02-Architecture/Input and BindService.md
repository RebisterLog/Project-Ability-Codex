# Input and BindService

Bindings live in `src/shared/configs/Specs.luau` under each spec's `Binds` table. A bind maps a skill id to an `Enum.KeyCode` or `Enum.UserInputType` value (mouse buttons and touch are supported).

## How input reaches a skill

```
key / mouse / touch
  -> client BindService
  -> packet StartSkill(skillId)
  -> server SkillService validates
  -> spec:ActivateSkill(skillId)
  -> Skill:Activate()
```

## Important behaviours

- **No Hold option.** While a key is down, the bind is re-requested and the server validates every request. There is a shared budget of roughly 12 packets/sec across all held keys. After release, `StopSkill` is repeated briefly so a dropped packet cannot leave a skill stuck.
- **Press-to-flip skills are excluded from repeat:** `Run` through its client `Toggle` flag; `Summon` through the explicit `NON_REPEATABLE` list in `BindService`.
- **Colliding binds:** candidates are sorted by slot (`Spec` before `SubSpec`) and then alphabetically by skill id. The first candidate that can be cast right now wins. A candidate blocked by cooldown, disabled state, missing skill or character state passes the key to the next one. If none can start, the highest-priority candidate keeps the key until release.
- Server validation is authoritative: cooldown, stun, ragdoll and alive state are checked before `Activate`. See [[Combat pipeline]].

## Typical bind table

```luau
Binds = {
    ["Punch"] = Enum.UserInputType.MouseButton1,
    ["Block"] = Enum.KeyCode.F,
    ["Dash"]  = Enum.KeyCode.C,
    ["Run"]   = Enum.KeyCode.LeftControl,
    ["Grab"]  = Enum.KeyCode.X,
}
```

Related: [[Spec and SubSpec]], [[Create a spec]], [[Data schemas and Proxy]].
