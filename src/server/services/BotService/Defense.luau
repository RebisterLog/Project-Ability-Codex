--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])
local Conditions = require(script.Parent.Conditions)
local SkillPriority = require(script.Parent.SkillPriority)
local Tags = require(script.Parent.Tags)

local DEFENSE_TAG = "Defense"
local ESCAPE_TAG = "Escape"
local COUNTER_TAG = "Counter"
local BLOCKABLE_TAG = "Blockable"
local PERFECT_BLOCKABLE_TAG = "PerfectBlockable"
local PERFECT_BLOCK_TAG = "PerfectBlock"

local BLOCKABLE_CONDITIONS = { "TARGET_BLOCKABLE", "TARGET_PERFECT_BLOCKABLE" }

export type RoleSkill = {
	Id: string,
	Tags: { BotsCharacters.SkillCharacter }?,
}

export type Roles = {
	Guard: string?,
	Escape: string?,
}

export type ReactionContext = {
	GuardId: string?,
	EscapeId: string?,
	GuardHeld: boolean,
	GuardOnCooldown: boolean,
}

export type Incoming = {
	Skill: {
		Data: {
			SkillCharacters: { string }?,
		},
	}?,
}

export type Decision = "Press" | "Hold" | "Escape" | "Ignore"

local Defense = {}

function Defense:HasTag(tags: { string }?, tag: string): boolean
	return Tags.Has(tags, tag)
end

function Defense:IsBlockable(tags: { string }?): boolean
	return self:HasTag(tags, BLOCKABLE_TAG)
		or self:HasTag(tags, PERFECT_BLOCKABLE_TAG)
		or self:HasTag(tags, PERFECT_BLOCK_TAG)
end

function Defense.ResolveRoles(
	skills: { RoleSkill },
	configurable: { [string]: BotsCharacters.SkillPreference }
): Roles
	local roles: Roles = {}

	for _, skill in skills do
		if not configurable[skill.Id] then continue end
		if not Defense:HasTag(skill.Tags, DEFENSE_TAG) then continue end
		if Defense:HasTag(skill.Tags, COUNTER_TAG) then continue end

		if Defense:HasTag(skill.Tags, ESCAPE_TAG) then
			roles.Escape = skill.Id
		elseif not roles.Guard then
			roles.Guard = skill.Id
		end
	end

	return roles
end

function Defense.IsHeldGuard(tags: { string }?): boolean
	return Tags.Has(tags, DEFENSE_TAG)
		and not Tags.Has(tags, ESCAPE_TAG)
		and not Tags.Has(tags, COUNTER_TAG)
end

function Defense.React(incoming: Incoming, context: ReactionContext): Decision
	local skill = incoming.Skill

	if skill and Defense:IsBlockable(skill.Data.SkillCharacters) and context.GuardId then
		if not context.GuardOnCooldown then return if context.GuardHeld then "Hold" else "Press" end
	end

	if context.EscapeId then return "Escape" end

	return "Ignore"
end

function Defense.ShouldDefend(mask: number, recentThreat: boolean): boolean
	if recentThreat then return true end

	return Conditions.HasAny(mask, BLOCKABLE_CONDITIONS)
end

function Defense.ShouldReleaseGuard(
	config: BotsCharacters.BotCharacterConfig,
	guardId: string,
	mask: number
): boolean
	if Conditions.Has(mask, "TARGET_PERFECT_BLOCKABLE") then return true end

	return SkillPriority.ShouldRelease(config, guardId, mask, nil)
end

return Defense
