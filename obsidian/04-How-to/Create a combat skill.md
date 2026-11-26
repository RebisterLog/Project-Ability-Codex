# Create a combat skill

## Checklist

1. **Pick the closest analog** from [[Skill contract and lifecycle]] — skills are deliberately not template-driven. `src/server/skills/TEMPLATE.luau` is the canonical stub.
2. **Header comment**: skill name, short description, and an `ASSETS` block listing every `Animation`, `Sound`, `Model` and `Stat` the skill uses.
3. **Module shape** (use `const` for top-level bindings):
   ```luau
   const Skill: types.SkillData = {
       DisplayName = "<Name>",   -- required
       Cooldown = 2,
       SkillCharacters = { "Hit" }, -- typed bot tags, not free text
   }
   function Skill.onInit(self) end
   function Skill.Activate(self) end
   function Skill.Interrupt(self) end
   return Skill
   ```
4. **onInit**: get services with `Crane:GetService`, read assets with `self:GetAsset("Animations/...")`, create the sequence in `self.Cleaner` (a `Crane.Buttler`), initialise per-skill state.
5. **Activate**: play the sequence ([[Sequencer]]) or use a promise/signal flow. On hit frames call [[Hitbox and targeting]], skip already-hit targets, call `CombatService:Attack` with [[AttackInfo and AttackData]]. Every bind is hold-to-cast, so long casts should release on `self.Deactivated` rather than assuming a single press.
6. **Interrupt**: stop the sequence and effects; release parameters through the cleaners. Usually nothing is needed here — `Skill:Init` already connects `CombatService.Interrupted` when `Interrupt` exists.
7. **Register**: add the module key to a spec's `Skills` table; it must match the module filename (the `~/skills/<Name>` / `@Specs/<Spec>/<Name>` value is only a convention). Add a bind in `src/shared/configs/Specs.luau` — a missing bind warns and skips the skill. See [[Spec and SubSpec]], [[Input and BindService]].

## Conventions

- Keep combat logic on the server. See [[Runtime boundaries]].
- Use `self.Cleaner` (a `Crane.Buttler`) for skill-lifetime resources and `seq.Cleaner` (also a Butler) for frame-scoped resources. There is no `self.Janitor` field on a skill.
- `SkillCharacters` are **typed bot tags** from `src/shared/bot-characters.luau` (`"Hit"`, `"Stun"`, `"Blockable"`, `"PerfectBlock"`, `"BlockBreak"`, ...), not free text. `Tag` is a separate `SkillData` field (e.g. `"OnlyForStand"`); `Checks` is a private table read by `Skill:Validate`.
- On a sequence the validator key is `Validator` (not `Validate`), and repeated hits use frame keys `Interval = N` / `Offset = M` rather than `if frame % N ~= 0 then return end`. A ranged frame entry is **not** a loop. See [[Sequencer]].
- `VFXService:StartEffect` / `StopEffect` take exactly three arguments: `(players, name, dataTable)`. There is no positional `RootPart` or animation argument. See [[VFX replication]].
- Dynamic asset keys are normal: `self:GetAsset("Animations/Punch" .. self.PunchCount)`. `BaseSpec` provides an asset fallback for shared skills.
- Use `function Skill.onInit(self)` style for new code; match the file when editing.

## Verification

- Cooldown and interrupt behave under stun/ragdoll.
- No duplicate hits during repeated frames (`AlreadyHit`).
- All effects and parameters are released on interrupt.
- All `GetAsset` paths resolve for every skin of the spec.
- There is no automated test runner. Format with `lune run tools/format.luau --fix --src`, then inspect with `lune run tools/context.luau` and `lune run tools/impact.luau <target>`; playtest in Studio.

Related: [[Combat pipeline]], [[Sequencer]], [[Attack hooks]], [[VFX replication]].
