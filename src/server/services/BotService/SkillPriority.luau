--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])
local Conditions = require(script.Parent.Conditions)

local DEFAULT_CONDITION_WEIGHT = 1
local DEFAULT_COMBO_WEIGHT = 1

local band = bit32.band

export type Candidate = {
	Data: {
		Id: string,
	},
}

export type ScoredSkill = {
	Id: string,
	Score: number,
}

local SkillPriority = {}
local TIES: { string } = {}

function SkillPriority:GetConditionWeight(config: BotsCharacters.BotCharacterConfig): number
	return config.ConditionWeight or DEFAULT_CONDITION_WEIGHT
end

function SkillPriority:IsEligible(options: BotsCharacters.SkillPreference, mask: number): boolean
	local required = Conditions.Mask(options.RequiredConditions)
	if band(mask, required) ~= required then return false end

	local forbidden = Conditions.Mask(options.ForbiddenConditions)
	if band(mask, forbidden) ~= 0 then return false end

	return true
end

function SkillPriority:IsPreferredDistance(
	preferred: { Min: number?, Max: number? },
	distance: number
): boolean
	local min = preferred.Min
	if min and distance < min then return false end

	local max = preferred.Max
	if max and distance > max then return false end

	return true
end

function SkillPriority.Score(
	config: BotsCharacters.BotCharacterConfig,
	options: BotsCharacters.SkillPreference,
	mask: number,
	distance: number,
	isCombo: boolean
): number
	local conditionWeight = SkillPriority:GetConditionWeight(config)
	local score = options.Priority or 0

	score += Conditions.Count(mask, options.PreferredConditions) * conditionWeight
	score -= Conditions.Count(mask, options.PenaltyConditions) * conditionWeight

	local preferred = options.PreferredDistance
	if preferred and SkillPriority:IsPreferredDistance(preferred, distance) then
		score += conditionWeight
	end

	if isCombo then
		score += config.ComboWeight or DEFAULT_COMBO_WEIGHT
	end

	return score
end

function SkillPriority.Select(
	config: BotsCharacters.BotCharacterConfig,
	candidates: { Candidate },
	mask: number,
	distance: number,
	comboSkillId: string?,
	blocked: { [string]: boolean }?
): ScoredSkill?
	local bestId: string? = nil
	local bestScore = 0

	table.clear(TIES)

	for _, candidate in candidates do
		local id = candidate.Data.Id
		if blocked and blocked[id] then continue end

		local options = config.Skills[id]
		if not options then continue end
		if not SkillPriority:IsEligible(options, mask) then continue end

		local maxDistance = options.Distance
		if maxDistance and distance > maxDistance then continue end

		local isCombo = comboSkillId ~= nil and id == comboSkillId
		local score = SkillPriority.Score(config, options, mask, distance, isCombo)

		if not bestId or score > bestScore then
			bestId = id
			bestScore = score
			table.clear(TIES)
			table.insert(TIES, id)
		elseif score == bestScore then
			table.insert(TIES, id)
		end
	end

	if not bestId then return nil end

	for _, id in TIES do
		if comboSkillId and id == comboSkillId then return { Id = id, Score = bestScore } end
	end

	return { Id = TIES[math.random(1, #TIES)], Score = bestScore }
end

function SkillPriority.ShouldRelease(
	config: BotsCharacters.BotCharacterConfig,
	skillId: string,
	mask: number,
	bestId: string?
): boolean
	local options = config.Skills[skillId]
	if not options then return true end

	if Conditions.HasAny(mask, options.HoldUntil) then return true end

	local holdWhile = options.HoldWhile
	if holdWhile and #holdWhile > 0 then return not Conditions.HasAny(mask, holdWhile) end

	if bestId == nil then return false end

	return bestId ~= skillId
end

return SkillPriority
