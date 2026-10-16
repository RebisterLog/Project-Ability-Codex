--!native
--!optimize 2

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])
const Conditions = require(script.Parent.Conditions)

--- Skill priority scoring for bots.
---
--- The module knows nothing about `Spec`, `Skill` or the world: it receives an
--- already filtered list of candidates, the mask of target conditions
--- (`Sense.Mask`, see `BotService/Conditions`) and the distance to it. Everything
--- else is pure arithmetic over the config, which is why it can be verified
--- without Studio.
---
--- The guard (`Block`) never reaches this module: the bot has a single action
--- slot and a defensive skill must not compete with an attack by weights. The
--- "should we block" question belongs to `BotService/Defense`.

const DEFAULT_CONDITION_WEIGHT = 1
const DEFAULT_COMBO_WEIGHT = 1

-- Bitwise operations come from `bit32`: the formatter version used here chokes on
-- the `&` and `|` operators.
const band = bit32.band

--- A candidate to use. Only the id is needed, everything else the scorer takes
--- from the config. Structurally compatible with `types.Skill`, so
--- `Spec:GetAvailableSkills()` can be passed as is.
export type Candidate = {
	Data: {
		Id: string,
	},
}

export type ScoredSkill = {
	Id: string,
	Score: number,
}

const SkillPriority = {}

--- Weight of a single soft condition for this bot.
const GetConditionWeight = function(config: BotsCharacters.BotCharacterConfig)
	return config.ConditionWeight or DEFAULT_CONDITION_WEIGHT
end

--- Hard groups: every `RequiredConditions` entry has to be met, and not a single
--- `ForbiddenConditions` entry.
const IsEligible = function(options: BotsCharacters.SkillPreference, mask: number): boolean
	const required = Conditions.Mask(options.RequiredConditions)
	if band(mask, required) ~= required then return false end

	const forbidden = Conditions.Mask(options.ForbiddenConditions)
	if band(mask, forbidden) ~= 0 then return false end

	return true
end

--- Bonus for landing inside the soft distance band.
const IsPreferredDistance = function(preferred: { Min: number?, Max: number? }, distance: number)
	const min = preferred.Min
	if min and distance < min then return false end

	const max = preferred.Max
	if max and distance > max then return false end

	return true
end

--- Priority of a single skill. `isCombo` tells whether it is the planned step.
---
--- The only place where the arithmetic lives: both the winner selection and the
--- hold check go through it, so the rules cannot drift apart.
function SkillPriority.Score(
	config: BotsCharacters.BotCharacterConfig,
	options: BotsCharacters.SkillPreference,
	mask: number,
	distance: number,
	isCombo: boolean
): number
	const conditionWeight = GetConditionWeight(config)
	local score = options.Priority or 0

	score += Conditions.Count(mask, options.PreferredConditions) * conditionWeight
	score -= Conditions.Count(mask, options.PenaltyConditions) * conditionWeight

	const preferred = options.PreferredDistance
	if preferred and IsPreferredDistance(preferred, distance) then
		score += conditionWeight
	end

	if isCombo then
		score += config.ComboWeight or DEFAULT_COMBO_WEIGHT
	end

	return score
end

--- Returns the skill with the highest priority, or `nil` when nothing fits.
---
--- `comboSkillId` is the skill currently in the plan: it gets `ComboWeight` and
--- wins every tie. That keeps the combo as the backbone of the behaviour, with
--- conditions only shifting it when they offer a strict advantage.
function SkillPriority.Select(
	config: BotsCharacters.BotCharacterConfig,
	candidates: { Candidate },
	mask: number,
	distance: number,
	comboSkillId: string?
): ScoredSkill?
	local best: ScoredSkill? = nil
	const ties: { string } = {}

	for _, candidate in candidates do
		const id = candidate.Data.Id
		const options = config.Skills[id]
		if not options then continue end
		if not IsEligible(options, mask) then continue end

		const maxDistance = options.Distance
		if maxDistance and distance > maxDistance then continue end

		const isCombo = comboSkillId ~= nil and id == comboSkillId
		local score = SkillPriority.Score(config, options, mask, distance, isCombo)

		if not best or score > best.Score then
			best = { Id = id, Score = score }
			table.clear(ties)
			table.insert(ties, id)
		elseif score == best.Score then
			table.insert(ties, id)
		end
	end

	if not best then return nil end

	-- Tie: the plan wins over conditions, everything else is random.
	for _, id in ties do
		if comboSkillId and id == comboSkillId then return { Id = id, Score = best.Score } end
	end

	return { Id = ties[math.random(1, #ties)], Score = best.Score }
end

--- Should the bot release a held skill right now.
---
--- Only the config rules live here: `HoldUntil` (emergency abort) and `HoldWhile`
--- (keep holding while at least one condition is met). The defense layer passes
--- no rival for the recompute fallback: the bot has a single action slot and the
--- question "who owns it" is answered by the posture, not by the attack rating.
--- `bestId` therefore stays available for attacking skills held as part of a combo.
---
--- Order:
--- 1. `HoldUntil` fired — emergency release, nothing is computed;
--- 2. `HoldWhile` is set — hold while at least one of its conditions is met;
--- 3. `HoldWhile` is not set — fallback by recomputation: release as soon as the
---    skill is no longer the best candidate. If no candidates are left (all are on
---    cooldown) holding still makes sense, so there is nothing to release to.
---
--- An empty list counts as a missing field: `{}` is truthy in Luau, and without
--- this check `HoldWhile = {}` would mean "release every frame".
function SkillPriority.ShouldRelease(
	config: BotsCharacters.BotCharacterConfig,
	skillId: string,
	mask: number,
	bestId: string?
): boolean
	const options = config.Skills[skillId]
	if not options then return true end

	if Conditions.HasAny(mask, options.HoldUntil) then return true end

	const holdWhile = options.HoldWhile
	if holdWhile and #holdWhile > 0 then return not Conditions.HasAny(mask, holdWhile) end

	if bestId == nil then return false end

	return bestId ~= skillId
end

return SkillPriority
