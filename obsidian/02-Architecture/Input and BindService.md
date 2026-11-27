# Input and BindService

Bindings live in `src/shared/configs/Specs.luau` under each spec's `Binds` table. A bind maps a skill id to an `Enum.KeyCode` or `Enum.UserInputType` value (mouse buttons and touch are supported). A per-spec override can replace those defaults at equip time.

## Custom binds and the skill bar

`src/shared/configs/Binds.luau` is the allow-list of keys a player may assign. Its `HiddenSkills` table lists skill ids that get no cell on the skill bar at all (`Run` today), while their binds keep working through `BindService`. The client skill bar (`SkillBarComponent` + `SkillBarView`) shows only enabled, bound skills, ordered `Spec` before `SubSpec`. It uses `Parameters.ReleaseTime` from the Proxy for the drain animation and the numeric timer; no total cooldown duration is replicated.

Holding the left mouse button on a cell for one second enters rebinding mode. The next key from the allow-list is sent as `RebindSkill({ SpecName, SkillId, Bind })`, where `Bind` is `tostring(EnumItem)` because ByteNet has no enum codec. `SpecModule:Rebind` validates spec ownership and skill membership, stores the bind in `PlayerSaveData.SpecBinds[specName][skillId]`, and applies it at once to the live skill with `skill:SetBind` when that spec is equipped.

Binds are keyed by **spec name**, not by the owned spec UUID, so switching specs and returning restores the player's choices. `SpecModule:EquipSpec` converts the saved strings back to EnumItems through the same allow-list and passes them to `SpecService:CreateSpec` as per-character overrides, which take precedence over `Specs.luau`. Duplicate keys between skills are allowed and resolved by the slot/skill-id ordering described below. `BindService.SkillActivated` fires once per press and briefly shrinks the cell via `scope:Spring`.

Cells use an explicit `LayoutOrder`: all `Spec` skills first, then `SubSpec`, alphabetical inside each slot. A spec may define `Palette = { BackgroundColor, NameColor, CooldownColor, TimerColor, BindColor, BindTextColor }` in `Specs.luau` — one colour per element of a cell; a subspec has its own entry and therefore its own palette. Any missing colour falls back to the built-in value.

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

`StartSkill` is a struct, not a bare string: `{ Id: string, AimPoint: Vector3? }`. Only skills with `AimRequired = true` in their server data send a point; every other bind sends `nil`, so the shared client→server budget is unchanged for existing skills.

- **Normal camera:** the point is `Mouse.Hit.Position`, clamped to `MAX_AIM_DISTANCE` (120 studs) from the character's `HumanoidRootPart`.
- **ShiftLock:** when `TargetLockService.Locked` is true or `UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter`, the cursor is pinned in the centre and `Mouse.Hit` is meaningless. The client instead sends `root.Position + root.CFrame.LookVector * MAX_AIM_DISTANCE` — the farthest point along the character's look vector.
- **No character / no `Mouse.Hit`:** the same look-vector fallback is used.

The server never trusts the point for hit resolution: it is only a direction/aim hint for projectile launch. `SkillService:ActivateSkill(character, skillId, aimPoint)` forwards it through `Spec:ActivateSkill` into `Skill:Activate(aimPoint)` and then `SkillData.Activate(self, aimPoint)`. Skills that do not need aim simply ignore the extra argument.

The client clamps the point in `BindService:AimPointFor` (120 studs from the caster's `HumanoidRootPart`); `SkillService:ActivateSkill` now applies the same clamp on the server, so bot-generated points and Studio Bridge calls are covered too. A `nil` point is left untouched. Only skills whose server data sets `AimRequired = true` receive a point (currently `Knives`): the flag is replicated in `Skills[slot][id].Parameters.AimRequired` and read by both the client and bots. This avoids sending a vector for every held bind.

## Important behaviours

- **No Hold option.** While a key is down, the bind is re-requested and the server validates every request. There is a shared budget of roughly 12 packets/sec across all held keys. After release, `StopSkill` is repeated briefly so a dropped packet cannot leave a skill stuck.
- **Press-to-flip skills are excluded from repeat:** `Run` and `Summon` declare `Toggle = true` in their server skill data, replicated as `Parameters.Toggle`.
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
