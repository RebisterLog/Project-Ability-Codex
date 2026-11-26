---
name: create-combat-skill
description: "Generate new Luau combat skills for Project-Ability-Codex (PAC) — src/server/skills/*.luau with correct SkillData, Sequencer frames, CombatService Hitbox/Attack, VFX effects, asset lookup and registration in specs/Specs.luau. Use this skill whenever the user asks to add, write, implement, create or refactor a combat ability, skill or move in PAC: «создай скилл», «напиши абилку», «новый приём для персонажа», «добавь удар/блок/чардж», even if they never say the words skill module. This skill produces the actual Luau module; for explanations of how PAC combat works, use pac-combat. Do NOT use it for a Russian ТЗ/technical design doc (use create-tech-spec) or for whole character specs, skins and binds (use create-spec)."
---

# Create Combat Skill

Create a combat skill module under `src/server/skills/` and wire it into a spec. Skills in PAC are deliberately **not** template-driven: each one defines its own private data and flow. The only real contract is that the module returns a table shaped like `types.SkillData`.

## Workflow

1. **Find the closest existing skill** and read it — do not invent a structure. `src/server/skills/TEMPLATE.luau` is the canonical stub; `patterns.md` maps intent → example file.
2. **Copy the idiom, not the numbers**: `const` bindings, `function Skill.onInit(self)`, `self.Cleaner` (a `Crane.Buttler`), `self:GetAsset("Category/Name")`.
3. **Pick one flow**: a Sequencer (most attacks), a promise over signals (Block), or a direct toggle (Run).
4. **Read only the references you need**, from the index at the bottom.
5. **Register**: add the module key to the spec's `Skills` table and a bind to `src/shared/configs/Specs.luau`.
6. **Verify** with `lune run tools/format.luau --fix --src`, then `lune run tools/context.luau` / `lune run tools/impact.luau <target>`. There is no test runner; sanity-check in Studio.

## Rules that break code if ignored

These are the highest-frequency mistakes. They are expanded in the references.

- `VFXService:StartEffect/StopEffect` take **exactly three arguments**: `(players, effectName, dataTable)`. Never pass `RootPart` or an animation as a positional argument.
- Skills own `self.Cleaner` (Buttler), **not** `self.Janitor`. Sequences own `seq.Cleaner`.
- A Sequencer validator key is `Validator`, not `Validate`. `Validate = function() ... end` inside a sequence is silently ignored (and exists as dead code in a couple of older skills).
- Repeated frames use `Interval = N` / `Offset = M` keys on the frame entry, not `if frame % N ~= 0 then return end`.
- `SkillCharacters` are **typed bot tags** (`"Hit"`, `"Stun"`, `"Blockable"`, `"PerfectBlock"`, `"BlockBreak"`, ...), not free-form strings. `OnlyForStand` is a `Tag` value, `BaseSpec` is the asset-fallback field, `Checks` is a private table read by `Skill:Validate`.
- A **guard-breaking** hit must set `PerfectBlockable = false`: a perfect block parries first, and `BlockBreak` never applies in that branch (`Block.luau:89-96`). Leaving it `true` produces a finisher that can never break a held guard.
- `DisplayName` is required. The module **filename** is the skill `Id` and must equal the key in the spec's `Skills` table; the string value (`~/skills/...`) is only a convention.
- Every bind is hold-to-cast on the server. Long casts should release on `self.Deactivated` rather than assuming a single press.
- Top-level bindings use `const`. Add `--!native` / `--!optimize 2` only for genuinely hot server combat code.

## Minimal correct stub

```luau
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const types = require(ServerScriptService.server.types)

const Skill: types.SkillData = {
	DisplayName = "NAME",
	Cooldown = 2,
	AttackInfo = {
		Hitbox = { Size = Vector3.new(7, 7, 7), Offset = CFrame.new(0, 0, -3) },
		Damage = 15,
		Block = {
			Blockable = true,
			PerfectBlockable = false,
			BlockBreak = false,
			BlockCancel = false,
			BlockIgnore = false,
		},
		Stun = { Priority = Enums.Stun.Medium, Duration = 0.7 },
	},
}

function Skill.onInit(self)
	const CombatService = Crane:GetService("CombatService")
	self.AlreadyHit = {}
	self.Sequence = self.Cleaner:Add(CombatService.CreateSequence(self.Character, {
		Frames = {
			{ 0, function(seq)
				const anim = self:GetAsset("Animations/NAME")
				seq.Cleaner:Add(function()
					VFXService:StopEffect(Players:GetPlayers(), "Animation", {
						Character = self.Character.instance, Animation = anim.Animation,
					})
				end)
			end },
			{ 30, function()
				const Targets = CombatService:Hitbox({
					Skill = self, Caster = self.Character,
					Info = self.Data.AttackInfo.Hitbox,
				})
				for _, Target in Targets do
					if table.find(self.AlreadyHit, Target) then continue end
					CombatService:Attack({
						Attacker = self.Character, Victim = Target,
						Info = self.Data.AttackInfo,
					}):andThen(function(data: types.AttackData)
						if data.State.Success then table.insert(self.AlreadyHit, Target) end
					end)
				end
			end },
			{ 45 },
		},
	}))
end

function Skill.Activate(self)
	if self.Sequence then
		self.Sequence:Play()
		self.Sequence:Await()
	end
end

function Skill.Interrupt(self)
	if self.Sequence then self.Sequence:Stop() end
end

return Skill
```

Treat this as a skeleton: real skills frequently differ, and `Enums`/`VFXService` locals must be declared as in `TEMPLATE.luau`.

## Header comment block

Put a block comment above `const Skill` describing the skill and **every asset it reads**, so the spec's skin config can be checked:

```luau
--[=[ SKILL_NAME

   Short description: what it does and when it is used.

   ASSETS:
   Animations
      NAME : Animation for [action]
   Sounds
      NAME : Sound for [effect]
   Models
      NAME : (BasePart) VFX part for [purpose]
   Stats
      NAME : CFrame / Vector3 / number used for [tuning]
]=]
```

Use `GetAsset` for required assets and `TryGetAsset` for optional ones with an `or` default. Omit unused categories. Note: only a minority of existing skills have this block — still write it for new code.

## Registration

```luau
-- src/server/specs/<Spec>.luau
Skills = {
	["YourSkill"] = "~/skills/YourSkill",              -- shared
	["YourSkill"] = "@Specs/<Spec>/YourSkill",          -- spec-unique
}

-- src/shared/configs/Specs.luau, inside the spec's Binds
["YourSkill"] = Enum.KeyCode.R,
```

The key must match the module filename. A missing bind produces a warning and the skill is skipped.

## References — read when you need the detail

| File | Read when... |
|---|---|
| `references/contract.md` | defining SkillData fields, lifecycle, `GetAsset`/`BaseSpec`, `Checks`, `Tag`, cooldowns, typed bot tags |
| `references/combat-service.md` | building hitboxes, attacks, block/stun/knockback data, lag compensation, `CreateGrab`, `Equip` |
| `references/sequencer.md` | authoring frames, repeated hits, validators, cleanup, pause/resume |
| `references/vfx.md` | playing/stopping any effect — exact 3-argument signatures and payload fields |
| `references/patterns.md` | implementing combo, dash, grab, barrage, block or stand-tagged skills |
| `references/registration.md` | choosing the analog file, placing the module, debugging binds/IDs |
