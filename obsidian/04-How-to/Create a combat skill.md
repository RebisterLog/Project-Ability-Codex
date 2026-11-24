# Create a combat skill

## Checklist

1. **Pick the closest analog** from [[Skill contract and lifecycle]] — do not start from a rigid template.
2. **Header comment**: skill name, short description, and an `ASSETS` block listing every `Animation`, `Sound`, `Model` and `Stat` the skill uses.
3. **Module shape**:
   ```luau
   local Skill: types.SkillData = {
       DisplayName = "<Name>",
       Cooldown = 2,
       SkillCharacters = { "Hit" },
   }
   function Skill:onInit() end
   function Skill:Activate() end
   function Skill:Interrupt() end
   return Skill
   ```
4. **onInit**: get services with `Crane:GetService`, read assets with `self:GetAsset("Animations/...")`, create the sequence in `self.Janitor`, initialise per-skill state.
5. **Activate**: play the sequence ([[Sequencer]]) or use a promise/signal flow. On hit frames call [[Hitbox and targeting]], skip already-hit targets, call `CombatService:Attack` with [[AttackInfo and AttackData]].
6. **Interrupt**: stop the sequence and effects; release parameters through the cleaners.
7. **Register**: add the module path to a spec (`~/skills/<Name>` or `@Specs/<Spec>/<Name>`) and add a bind. See [[Spec and SubSpec]], [[Input and BindService]].

## Conventions

- Keep combat logic on the server. See [[Runtime boundaries]].
- Use `self.Janitor` for service-level resources and `seq.Cleaner` for frame-scoped resources.
- `SkillCharacters` is a freeform tag list; no fixed enum.
- Dynamic asset keys are normal: `self:GetAsset("Animations/Punch" .. self.PunchCount)`.
- Prefer colon methods for new code; match the file when editing.

## Verification

- Cooldown and interrupt behave under stun/ragdoll.
- No duplicate hits during looping frames (`AlreadyHit`).
- All effects and parameters are released on interrupt.
- `lune run tools/format.luau --fix --src`.

Related: [[Combat pipeline]], [[Sequencer]], [[Attack hooks]], [[VFX replication]].
