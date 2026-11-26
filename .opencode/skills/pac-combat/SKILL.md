---
name: pac-combat
description: "Compact architecture reference for PAC combat in Project-Ability-Codex — how the skill lifecycle, Sequencer, AttackHook/Hook, AttackInfo/AttackData.State, hitboxes, character parameters, block resolution and VFX replication fit together. Use this skill whenever the user asks how PAC combat works, explains a pipeline, asks what a field/state means, or compares combat subsystems: «как устроен бой», «что делает AttackHook», «какие параметры есть у персонажа», «как реплицируются VFX». Do NOT use it to write a new Luau skill module (use create-combat-skill), a character spec (use create-spec), or a Russian ТЗ (use create-tech-spec)."
---

# PAC Combat — architecture reference

This is a **map**, not a tutorial. For authoring code, use `create-combat-skill` (modules) and `create-spec` (characters/skins); their `references/` hold the full signatures and copyable snippets. Canonical long-form notes live in `obsidian/03-Combat/` with RU mirrors in `obsidian/i18n/ru/03-Combat/`.

## Pipeline

`StartSkill` packet → `SkillService` → `Skill:Validate()` (`Checks`, `NoSkillCast`, enabled, `Restand`, cooldown; metadata from `ClientStateService`) → `Spec:ActivateSkill` (global busy check) → `Skill:Activate` (sets `Active`/`Holding`, adds the `CastingSkill` guard for the whole cast) → Sequencer frames → `CombatService:Hitbox` → `CombatService:Attack` → Hook stacks → VFX packets + Proxy replication. `Deactivate` fires `Deactivated` only while `Holding`; `Interrupt` runs only while `Active` and is auto-connected to `CombatService.Interrupted` when the module defines `Interrupt`.

Construction: `Character.SetSpec:187-220` → `SpecService.CreateSpec:74-120` (skills by **module name**, binds required) → `created:Init({ Movement = slot == "Spec" })` at `:217` → `Spec.Init:37-63` → each `Skill.Init:172-192`.

## Sequencer

`CombatService.CreateSequence(character, data)` clamps speed from the `Timescale` parameter (0..10). Frame entries are `{start, callback?, end?}` with optional `Interval = N` / `Offset = M`; a ranged entry fires repeatedly **while the playhead moves forward** — it is not a loop.

- Validator key is `Validator` (a `Validate = ...` key is ignored — older skills contain that dead pattern).
- `seq.Cleaner` is a `Crane.Buttler`: `Add`, `Set(label, obj)`, `Remove`, `Has`, `Clean`, `Destroy`.
- `Play`, `Await`, `Stop`, `Pause`, `Resume`, `IsPlaying`, `IsPaused`, `AdjustSpeed` exist; there is no `CurrentFrame` accessor.

## Hooks and signals

`CombatService:onStart` owns `AttackHook = Hook.new("Attack", { "Precast", "Cast", "Postcast" })` and `HealHook`; built-in hooks are ModuleScripts under `CombatService/Hooks/`. Registration is `Hook:Hook(stack, priority, callback)` — it generates a GUID internally and returns an **unhook closure** to store in `self.Cleaner`; there is no caller-supplied hook name. A callback returning `false`/`nil` aborts the chain.

Skills normally use signals instead of owning hooks: `CombatService.Casted`, `Attacked` (with `"Precast"|"Cast"|"Postcast"`), `Interrupted`. `Skill:GetAsset` failures soft-stop the active sequence before raising.

## Attacks

`CombatService:Attack({ Attacker?, Victim, Skill?, Info })` returns a Promise; `Info` is cloned and deep-frozen, `OriginalInfo` is preserved. Result carries `State`, `DamageDealt`, `NoDeathDeferred`.

`AttackInfo` may contain `Hitbox` (a skill-private convention, **not** part of the type), `Damage`, `Priority`, `Restand`, `Block`, `Stun`, `Bleed`, `Burn`, `Knockback`, `Ragdoll`, `Angular`, `HitEffects`, `HitSounds`, `HitAnimations`.

All five `Block` fields are **required booleans**: `Blockable`, `PerfectBlockable`, `BlockBreak`, `BlockCancel`, `BlockIgnore`. Resolution order (`shared/combat/Block.luau:70-101`): no block → nothing; `BlockIgnore` dominates; a perfect block against `PerfectBlockable = true` parries and `BlockBreak` **never fires** — a guard breaker therefore sets `PerfectBlockable = false`; otherwise `Blockable`/`BlockBreak` apply. Blocked hits yield `Absorbed`, which strips Damage, Ragdoll, Restand, Stun, Bleed, HitEffects, Knockback and Angular.

`AttackData.State`: `Success`, `Continue`, `Blocking`, `Blocked`, `BlockBroken`, `BlockCanceled`, `PerfectBlocking`, `PerfectBlocked`, `BlockIgnored`, `IFrames`, `Armored`, `Absorbed` (plus an untyped `Ragdolled`). Enums: `Stun` 0/10/20/30, `IFrames` Ragdoll 10 / Dodge 15 / Grab 50 / True 10000; `StunTime`, `StunSpeed`, `Ragdoll`, `CastSpeed` also exist. Knockback presets: `"Tap"`, `"Shove"`, `"Slam"`, `"Launch"`; `Stiffness` defaults to `math.huge`, `MaxForce` to `"Auto"` (may be a `Vector3`), `Hold` is mover lifetime.

## Hitbox

`CombatService:Hitbox({ Skill?, Caster, Info })` uses `GetPartBoundsInBox` for a `Vector3` `Size` and a radius query for a number. `Origin` defaults to `RootPart.CFrame` and overrides lag compensation. `Info.MovementCorrection = true` enables bounded melee lag compensation: `ClientStateService:GetMetadata(Caster).Predicted` when available, otherwise a velocity heuristic clamped to 2 studs. Also available: `Offset`, `SortByDistance`, `CanQueryCaster`, `Parameters` (default filters `workspace.Live`), `Debug`. A `Skill` fires `Casted` in a spawned task.

## Character parameters

`AddParameter(name, value)` returns `{ Value, Cleaner, Destroy }`; layers fold by parser, not "newest wins": lowest for `MaxWalkSpeed`/`MaxJumpPower`, highest for `MinWalkSpeed`/`IFrames`, priority for `Stun`, multiplicative for `Timescale`/damage/cooldown multipliers, OR for booleans, last for `CastingSkill`. Names include `MaxWalkSpeed`, `MinWalkSpeed`, `MaxJumpPower`, `IFrames`, `Stun`, `Armor`, `Timescale`, `Ragdoll`, `Restrain`, `NoCollision`, `NoRotate`, `NoSkillCast`, `CastingSkill`, `CooldownMultiplier`, `DamageMultiplier`, damage/heal receival multipliers, `Bleeding`, `Burning`, `GodMode`, `Restand`, `NoDeath`, `DamageHold`, `HamonCharge`. Helpers: `GetParameter`, `SetParameterValue`, `RefreshParameter`, `WatchParameter`. Server code uses `const`.

## VFX

Exactly three arguments: `VFXService:StartEffect(players, kind, data)` / `StopEffect(...)`; `StartEffectExcept`/`StopEffectExcept` invert the audience. `players` accepts `Player` objects or character `Model`s. Per-kind payloads:

- **Animation**: start `{ Character: Model, Animation: clipTable, Speed?, Type?, AdjustSpeed? }`; stop `{ Character: Model, Animation: clip.Animation, FadeTime?, Overlay? }` — note the clip-table vs raw-instance asymmetry.
- **Sound**: `{ Origin: CFrame|Instance, Sound: Sound|clipTable, Volume?, MaxDistance?, MinDistance? }`.
- **EmitParticle**: `{ UUID?: number, Particle: BasePart|string, Origin, Offset?, UseForge? }`.
- **Highlight**: `{ Character?|Adornee?, UUID?, FillColor?, OutlineColor?, FillTransparency?, OutlineTransparency?, Lifetime?, Tween? }`.

Other kinds live in `src/shared/effects/` (`Barrage`, `EquipShell`, `CameraShake`, `ForgeVFXHold`, `EmitFolder`, `Hitbox`, …) — read the effect module before using one.

## Cleanup

Skill-lifetime objects go in `self.Cleaner` (Buttler), cast-lifetime objects in `seq.Cleaner`. Register VFX teardown once at frame 0; duplicating `StopEffect` in `Interrupt` stops the same effect twice and can fight a newer cast. `onDestroy` runs before `Cleaner:Destroy`.
