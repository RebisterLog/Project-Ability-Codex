--!native
--!optimize 2

const BotsCharacters = require(game:GetService("ReplicatedStorage").shared["bot-characters"])
const Conditions = require(script.Parent.Conditions)
const SkillPriority = require(script.Parent.SkillPriority)

--- Rules of the bot defense.
---
--- The module is pure: no Roblox calls at all, only tags and condition masks. No
--- combat state (Spec, cooldowns, active skills) reaches it — the decision is
--- taken outside and only already known facts come in. That is what makes "when
--- should the bot block" verifiable in `lune` instead of by eyeballing Studio.
---
--- Defense and attack are separated on purpose. The bot has a single action slot:
--- `Skill:Activate` returns early while a skill is active, and
--- `Spec:ActivateSkill` returns early while any skill is active. A guard picked by
--- a shared scorer together with the attacks would therefore lose on weights and
--- would not be pressed in time, and a guard pressed late gives no perfect block,
--- because the window is stamped at activation time.

const DEFENSE_TAG = "Defense"
const ESCAPE_TAG = "Escape"
const COUNTER_TAG = "Counter"

const BLOCKABLE_TAG = "Blockable"
const PERFECT_BLOCKABLE_TAG = "PerfectBlockable"
const PERFECT_BLOCK_TAG = "PerfectBlock"

--- Conditions that justify raising the guard. The list lives at module level
--- because `Conditions.Mask` caches by table identity: a literal built per tick
--- would miss the cache and allocate every frame.
const BLOCKABLE_CONDITIONS = { "TARGET_BLOCKABLE", "TARGET_PERFECT_BLOCKABLE" }

--- Skill description for role resolution: the id and the tags are enough.
export type RoleSkill = {
	Id: string,
	Tags: { BotsCharacters.SkillCharacter }?,
}

--- Who does what in a fight. `Guard` is the held shield, `Escape` the retreat.
export type Roles = {
	Guard: string?,
	Escape: string?,
}

--- Skill tags are plain strings rather than vocabulary constants:
--- `SkillCharacters` stores values like `"PerfectBlock"`, not keys.
const HasTag = function(tags: { string }?, tag: string): boolean
	return tags ~= nil and table.find(tags, tag) ~= nil
end

--- Is the hit blockable? Both spellings of the tag are accepted, the vocabulary
--- key and its value, otherwise a skill written with the value silently stops
--- being blocked.
const IsBlockable = function(tags: { string }?): boolean
	return HasTag(tags, BLOCKABLE_TAG)
		or HasTag(tags, PERFECT_BLOCKABLE_TAG)
		or HasTag(tags, PERFECT_BLOCK_TAG)
end

const Defense = {}

--- Splits the skills of a spec into defense roles.
---
--- The `Defense` tag owns the defense layer. `Escape` inside it is the retreat,
--- everything else is the guard. `Counter` is excluded: a counter attack is
--- offence, and handing it to the defense would make the bot strike instead of
--- blocking.
---
--- Iteration order does not matter: a spec has exactly one guard, and if there
--- were several the first one wins — choosing between two shields is meaningless.
function Defense.ResolveRoles(skills: { RoleSkill }): Roles
	const roles: Roles = {}

	for _, skill in skills do
		if HasTag(skill.Tags, DEFENSE_TAG) and not HasTag(skill.Tags, COUNTER_TAG) then
			if HasTag(skill.Tags, ESCAPE_TAG) then
				roles.Escape = skill.Id
			elseif not roles.Guard then
				roles.Guard = skill.Id
			end
		end
	end

	return roles
end

--- What the bot has to be known for deciding what to do with an incoming hit.
export type ReactionContext = {
	GuardId: string?,
	EscapeId: string?,

	GuardHeld: boolean,
	GuardOnCooldown: boolean,
}

--- An incoming hit: the tags of the attacking skill. The skill itself may be
--- missing — `Casted` also fires for utility hitboxes.
export type Incoming = {
	Skill: {
		Data: {
			SkillCharacters: { string }?,
		},
	}?,
}

--- `Press` is a fresh guard press, `Hold` keeps it, `Escape` retreats,
--- `Ignore` does nothing: there is nothing to block.
export type Decision = "Press" | "Hold" | "Escape" | "Ignore"

--- The decision for a single incoming hit.
---
--- Tags come from the hit itself and not from the condition mask: in the frame of
--- the impact the attacking skill may already have finished, and the mask would
--- have lost `Blockable` by then.
---
--- If the guard is already held the answer is `Hold`, not `Press`: an active
--- `Block` does not restart (`Skill:Activate` returns early on `Active`), so a
--- "fresh press" against a parryable attack would not refresh the window anyway.
--- The guard is therefore released ahead of time, on the
--- `TARGET_PERFECT_BLOCKABLE` condition (see `ShouldReleaseGuard`), so it is free
--- by the time the hit arrives.
---
--- Nothing blockable means retreat: a guard is useless against a parryable hit,
--- and the escape is the only defense left. This is only called for a real threat
--- (`Threat:Track`), so it does not turn into dashing on every single hit.
function Defense.React(incoming: Incoming, context: ReactionContext): Decision
	const skill = incoming.Skill

	if skill and IsBlockable(skill.Data.SkillCharacters) and context.GuardId then
		if not context.GuardOnCooldown then return if context.GuardHeld then "Hold" else "Press" end
	end

	if context.EscapeId then return "Escape" end

	return "Ignore"
end

--- Should the bot back off right now, that is, hand the slot to the defense.
---
--- The guard goes up for what a block can actually take. "The target is winding
--- up" is not enough on its own: a parryable or unblockable hit (`Grab`,
--- `CircularKick`) is answered with a counter attack, not with a retreat. That is
--- what made `Counter` with `RequiredConditions = TARGET_ATTACKING` reachable at
--- all: while no guard is needed the bot stays in the attack posture and the
--- scorer can pick it.
---
--- `recentThreat` means a hit has just landed. It outranks the conditions: the
--- impact window has passed and the only thing left is to back away.
function Defense.ShouldDefend(mask: number, recentThreat: boolean): boolean
	if recentThreat then return true end

	return Conditions.HasAny(mask, BLOCKABLE_CONDITIONS)
end

--- Should the bot release the guard right now.
---
--- A parryable attack is an exception that outranks any config rule: while the
--- guard is held the perfect-block window is not refreshed and the hit lands as a
--- normal block. So the guard is released as soon as such an attack appears, and
--- the fresh press arrives on the hit itself (`Defense.React`).
---
--- Everything else is decided by the config: `HoldUntil` (emergency abort) and
--- `HoldWhile` (keep holding while at least one condition is met) — see
--- `SkillPriority.ShouldRelease`.
function Defense.ShouldReleaseGuard(
	config: BotsCharacters.BotCharacterConfig,
	guardId: string,
	mask: number
): boolean
	if Conditions.Has(mask, "TARGET_PERFECT_BLOCKABLE") then return true end

	return SkillPriority.ShouldRelease(config, guardId, mask, nil)
end

return Defense
