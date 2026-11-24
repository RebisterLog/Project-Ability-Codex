--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])
local CombatSnapshot = require(script.Parent.CombatSnapshot)
local Defense = require(script.Parent.Defense)
local Tags = require(script.Parent.Tags)
local types = require(ServerScriptService.server.types)

export type Entry = {
	Skill: types.Skill,
	Spec: types.Spec,
}

export type SkillIndex = {
	ById: { [string]: Entry },
	Config: BotsCharacters.BotCharacterConfig,
	Roles: Defense.Roles,
	Candidates: { types.Skill },

	Find: (self: SkillIndex, id: string) -> (types.Skill?, types.Spec?),
	Collect: (
		self: SkillIndex,
		snapshot: CombatSnapshot.Snapshot,
		now: number,
		navBlocked: boolean,
		dodgeIntent: boolean,
		distance: number
	) -> { types.Skill },
	ResolveRoles: (
		self: SkillIndex,
		configurable: { [string]: BotsCharacters.SkillPreference }
	) -> Defense.Roles,
	SummonOwner: (self: SkillIndex) -> types.Spec?,
}

local SkillIndex = {}
SkillIndex.__index = SkillIndex

function SkillIndex.Find(self: SkillIndex, id: string): (types.Skill?, types.Spec?)
	local entry = self.ById[id]
	if not entry then return nil, nil end

	return entry.Skill, entry.Spec
end

function SkillIndex.Collect(
	self: SkillIndex,
	snapshot: CombatSnapshot.Snapshot,
	now: number,
	navBlocked: boolean,
	dodgeIntent: boolean,
	distance: number
): { types.Skill }
	table.clear(self.Candidates)

	for id, entry in self.ById do
		local tags = entry.Skill.Data.SkillCharacters
		if Defense.IsHeldGuard(tags) then continue end

		local options = self.Config.Skills[id]
		if not options then continue end

		-- Escape skills are dodges or deliberate distance-closers, never random
		-- fillers. Pathfinding owns the body; otherwise a real threat or the
		-- configured engagement band is enough to consider Dash.
		if Tags.Has(tags, "Escape") then
			if navBlocked then continue end

			local preferred = options.PreferredDistance
			local minRange = if preferred and preferred.Min then preferred.Min else 8
			local maxRange = options.Distance or 18
			local canEngage = distance >= minRange and distance <= maxRange

			if not dodgeIntent and not canEngage then continue end
		end

		local valid = CombatSnapshot.IsSkillValid(snapshot, entry.Skill, now)

		-- A stand toggle is a separate action: without it a Skill:Validate would
		-- reject the skill, so the same basic checks decide the candidate.
		local standState = options.StandSummon
		if
			not valid
			and standState ~= nil
			and snapshot.HasStand
			and snapshot.StandActive ~= standState
		then
			valid = CombatSnapshot.IsBasicValid(snapshot, entry.Skill, now)
		end

		if valid then table.insert(self.Candidates, entry.Skill) end
	end

	return self.Candidates
end

function SkillIndex.ResolveRoles(
	self: SkillIndex,
	configurable: { [string]: BotsCharacters.SkillPreference }
): Defense.Roles
	local roles: { Defense.RoleSkill } = {}

	for id, entry in self.ById do
		table.insert(roles, { Id = id, Tags = entry.Skill.Data.SkillCharacters })
	end

	self.Roles = Defense.ResolveRoles(roles, configurable)

	return self.Roles
end

function SkillIndex.SummonOwner(self: SkillIndex): types.Spec?
	local entry = self.ById.Summon
	return entry and entry.Spec or nil
end

return {
	new = function(
		character: types.Character,
		config: BotsCharacters.BotCharacterConfig
	): SkillIndex
		local byId: { [string]: Entry } = {}

		for _, spec in { character.SubSpec, character.Spec } do
			if not spec then continue end

			for id, skill in spec.Skills do
				if byId[id] then continue end

				byId[id] = { Skill = skill, Spec = spec }
			end
		end

		return setmetatable({
			ById = byId,
			Config = config,
			Roles = {},
			Candidates = {},
		}, SkillIndex) :: SkillIndex
	end,
}
