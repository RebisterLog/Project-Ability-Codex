# Input and BindService

Bindings live in `src/shared/configs/Specs.luau` under each spec's `Binds` table. A bind maps a skill id to an `Enum.KeyCode` or `Enum.UserInputType` value (mouse buttons and touch are supported).

## How input reaches a skill

```
key / mouse / touch
  -> client BindService
  -> packet StartSkill({ Id, AimPoint? })
  -> server SkillService validates
  -> spec:ActivateSkill(skillId, aimPoint)
  -> Skill:Activate(aimPoint)
```

## AimPoint (cursor position in world space)

`StartSkill` is a struct, not a bare string: `{ Id: string, AimPoint: Vector3? }`. Only the ids listed in `AIMED_SKILLS` in `BindService` send a point; every other bind sends `nil`, so the shared client→server budget is unchanged for existing skills.

- **Normal camera:** the point is `Mouse.Hit.Position`, clamped to `MAX_AIM_DISTANCE` (120 studs) from the character's `HumanoidRootPart`.
- **ShiftLock:** when `TargetLockService.Locked` is true or `UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter`, the cursor is pinned in the centre and `Mouse.Hit` is meaningless. The client instead sends `root.Position + root.CFrame.LookVector * MAX_AIM_DISTANCE` — the farthest point along the character's look vector.
- **No character / no `Mouse.Hit`:** the same look-vector fallback is used.

The server never trusts the point for hit resolution: it is only a direction/aim hint for projectile launch. `SkillService:ActivateSkill(character, skillId, aimPoint)` forwards it through `Spec:ActivateSkill` into `Skill:Activate(aimPoint)` and then `SkillData.Activate(self, aimPoint)`. Skills that do not need aim simply ignore the extra argument.

The client clamps the point in `BindService.aimPointFor` (120 studs from the caster's `HumanoidRootPart`); `SkillService:ActivateSkill` now applies the same clamp on the server, so bot-generated points and Studio Bridge calls are covered too. A `nil` point is left untouched. Only opted-in skills receive a point: the client uses the `AIMED_SKILLS` set in `BindService` (currently `MarkedKnives`), while bots read `AimRequired = true` from the skill data. Keeping the client list explicit avoids sending a vector for every held bind.

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
