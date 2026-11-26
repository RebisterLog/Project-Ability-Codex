---
name: create-spec
description: "Generate complete PAC character specs in Project-Ability-Codex — src/server/specs/Name.luau, src/shared/configs/Skins/Name/*.luau with helpers and inheritance, src/shared/configs/Specs.luau registration (including Type = SubSpec), unique skill modules and Studio asset layout. Use this skill whenever the user asks to add, create, implement or rework a character, stand, spec, subspec, skin or their binds/assets: «создай персонажа», «новый стан», «добавь скин», «сделай субспец», even if they never say the word spec. This skill produces the actual Luau modules and config entries. Do NOT use it for a Russian ТЗ/technical design doc (use create-tech-spec) or for a single combat ability module (use create-combat-skill)."
---

# Create Spec

A **spec** is a character's skill set, assets and config bundled together. This skill creates the Luau side of a spec (and describes the Studio asset layout); the actual Animation/Sound/Model instances live in Studio, not in the repo.

## What a spec consists of

| Piece | Location | Required? |
|---|---|---|
| Spec module | `src/server/specs/<Name>.luau` | yes |
| Skin config(s) | `src/shared/configs/Skins/<Name>/None.luau` (+ extra skins) | yes |
| Public config | `src/shared/configs/Specs.luau` entry | yes |
| Skill modules | `src/server/skills/*.luau`, `src/server/skills/<Name>/*.luau` | yes |
| Studio assets | `ReplicatedStorage.assets.<Name>.<Skin>.*` | yes (Studio-side) |
| Bot config | `src/shared/configs/Bots/<Name>.luau` | optional |
| Extra skins | `src/shared/configs/Skins/<Name>/<Skin>.luau` | optional |

There is no asset folder or generator in the repo — `default.project.json` maps only `shared`, `server`, `client`.

## Workflow

1. Decide the **slot**: normal spec, or `Type = "SubSpec"` (e.g. a Hamon stylesheet layered onto a stand user).
2. Write the **spec module**: `Skills` table + optional `onInit` for weapons/stand models.
3. Write the **`None` skin**: import `helpers.luau`, reference `ReplicatedStorage.assets.<Name>.None.*`, include every animation/sound/model/VFX that the skills read.
4. Write any **extra skins** as partial overrides — `Skins/init.luau` recursively merges them into `None`.
5. Register in **`Specs.luau`** with `DisplayName`, `IsPublic`, optional `Type`, and a **bind per skill**.
6. Create/reuse **skill modules** (use `create-combat-skill` for the bodies).
7. Create the corresponding **Studio asset instances**.
8. Verify with `lune run tools/format.luau --fix --src`, `lune run tools/context.luau`, `lune run tools/impact.luau <target>`; playtest in Studio.

## Rules that break code if ignored

- Use `const`, not `local`, for top-level bindings. The old `Configuration.ConfigsFolder.Value` indirection is gone: configs live at `ReplicatedStorage.shared.configs`.
- The `Skills` map's values (`~/skills/Dash`, `@Specs/Name/Skill`) are **naming conventions only**. Resolution is by module name; the key must equal the skill module's filename.
- Skin configs use `helpers.luau` factories (`idleAnimation`, `movementAnimation`, `actionAnimation`, `loopedAnimation`, `sound`). Real asset keys are `Idle/Walk/Run/Jump/FreeFall`, `Punch1..4`, `Dash*`, `Block`, `Grab`/`GrabThrow`/`GrabThrowVictim`, `VFXs`, `Stand` — not the old `StandOffGrab*`/`PunchHit`/`StartHitFrame`/`EndHitFrame`.
- `Stats.Grab` only needs `AnimationOffset` and `FinalFrame` — the other frame fields are never read by `Grab.luau`.
- Binds are **required**: a missing bind warns and skips the skill. Every bind is hold-to-cast; there is no `Hold` field.
- A SubSpec is declared with `Type = "SubSpec"` in `Specs.luau` — that is the single source of truth for slot routing. The main spec owns body movement animations; the subspec does not (`Spec:Init({ Movement = false })`).
- Non-default skins need explicit ownership (`addSkin`) and equip (`changeSkin`) commands; they are not automatically available to players.
- `ReplicatedStorage.assets` is lowercase `assets`; there is no `Music/` folder in use.

## Minimal examples

```luau
-- src/server/specs/Name.luau
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Configs = ReplicatedStorage.shared.configs
const types = require(ServerScriptService.server.types)

const Spec = {
	Skills = {
		["Dash"] = "~/skills/Dash",
		["Punch"] = "~/skills/Punch",
		["Block"] = "~/skills/Block",
		["Run"] = "~/skills/Run",
		["UniqueSkill"] = "@Specs/Name/UniqueSkill",
	},

	onInit = function(self: types.Spec)
		-- e.g. self.Cleaner:Clone(model) or CombatService:Equip(self.Character, model)
	end,
}

return Spec
```

```luau
-- src/shared/configs/Skins/Name/None.luau
const Assets = game:GetService("ReplicatedStorage").assets
const Animations = Assets.Name.None.Animations
const Sounds = Assets.Name.None.Sounds
const Models = Assets.Name.None.Models
const Helpers = require(script.Parent.Parent.helpers)
const idleAnimation = Helpers.idleAnimation
const movementAnimation = Helpers.movementAnimation
const actionAnimation = Helpers.actionAnimation
const sound = Helpers.sound

return {
	Animations = {
		Idle = idleAnimation(Animations.User.Movements.Idle),
		Walk = movementAnimation(Animations.User.Movements.Walk),
		Run = movementAnimation(Animations.User.Movements.Run),
		Punch1 = actionAnimation(Animations.User.Punches.Punch1),
		Block = actionAnimation(Animations.User.Block),
		Grab = actionAnimation(Animations.User.GrabStart),
		GrabThrow = actionAnimation(Animations.User.GrabHit),
		GrabThrowVictim = actionAnimation(Animations.Enemy.Grab),
		UniqueSkill = actionAnimation(Animations.User.UniqueSkill),
	},
	Sounds = {
		Punch1 = sound(Sounds.Punches.Punch1),
		Grab = sound(Sounds.GrabStart),
		Grabbed = sound(Sounds.GrabHit),
		UniqueSkill = sound(Sounds.UniqueSkill),
	},
	Models = { DashEffect = Models.DashEffect },
	Stats = {
		Grab = {
			AnimationOffset = CFrame.new(0, 0, -4) * CFrame.Angles(0, math.pi, 0),
			FinalFrame = 75,
		},
	},
}
```

```luau
-- src/shared/configs/Specs.luau (entry)
["Name"] = {
	DisplayName = "Name",
	IsPublic = true,
	Binds = {
		["Dash"] = Enum.KeyCode.C,
		["Block"] = Enum.KeyCode.F,
		["Punch"] = Enum.UserInputType.MouseButton1,
		["Run"] = Enum.KeyCode.LeftControl,
		["UniqueSkill"] = Enum.KeyCode.E,
	},
}
```

## References — read when you need the detail

| File | Read when... |
|---|---|
| `references/spec-module.md` | writing the spec module, `Skills` paths, `onInit` weapon/stand attachment, real examples |
| `references/skins.md` | writing `None` or extra skins, helpers, merge/inheritance, asset keys, owned skins |
| `references/config-and-assets.md` | `Specs.luau`, binds, SubSpec routing, Studio assets, bot configs, lifecycle, verification |
