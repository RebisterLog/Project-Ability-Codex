--!native
--!optimize 2

const BotsCharacters = require(game:GetService("ReplicatedStorage").shared["bot-characters"])
const SkillPriority = require(script.Parent.SkillPriority)
const types = require(game:GetService("ServerScriptService").server.types)

--- Attack layer: skill selection by priority and combo progression.
---
--- There is no defense here and there must not be one. The bot has a single
--- action slot, and the guard must not compete with an attack by weights: on a
--- tie it would win and occupy the slot instead of the attack, and a guard
--- pressed late does not produce a perfect block. The "should we block" question
--- is answered by `BotService/Defense`.
---
--- The escape skill stays a candidate: it is also part of combos, so the attack
--- layer cannot be denied it. Defense has the first move, but while the slot is
--- free the escape is available as an attacking move as well.

type Host = {
	Config: BotsCharacters.BotCharacterConfig,
	Character: types.Character,
	Combo: BotsCharacters.SkillCombo,
	ComboIndex: number,
	Random: Random,
}

--- Candidates are reused between ticks: the scorer only reads them and never
--- yields, so there is no reason to build a new table every frame.
const CANDIDATES: { types.Skill } = {}

const CollectCandidates = function(spec: types.Spec, guardId: string?): { types.Skill }
	table.clear(CANDIDATES)

	for id, skill in spec.Skills do
		if id ~= guardId and skill:Validate() then table.insert(CANDIDATES, skill) end
	end

	return CANDIDATES
end

const Attack = {}

--- An empty combo is allowed: the plan then gives a bonus to nobody and the
--- choice is fully driven by conditions.
function Attack.RollCombo(
	config: BotsCharacters.BotCharacterConfig,
	random: Random
): BotsCharacters.SkillCombo
	const combos = config.Combos
	if not combos or #combos == 0 then return {} end

	return combos[random:NextInteger(1, #combos)]
end

--- One step of the attack: slot busy, leave; no candidates, leave; otherwise
--- activate the winner.
function Attack.Step(host: Host, mask: number, distance: number, guardId: string?)
	const spec = host.Character.Spec
	if not spec then return end

	if spec:CheckActiveSkills() then return end

	const combo = host.Combo
	const comboSkillId = combo[host.ComboIndex]

	const candidates = CollectCandidates(spec, guardId)
	if #candidates == 0 then return end

	const best = SkillPriority.Select(host.Config, candidates, mask, distance, comboSkillId)
	if not best then return end

	-- Deviating from the plan (a skill outside the combo was picked) does not
	-- advance the index: the combo stays the same, conditions just overrode it
	-- for now.
	if comboSkillId == best.Id then
		host.ComboIndex += 1

		if host.ComboIndex > #combo then
			host.ComboIndex = 1
			host.Combo = Attack.RollCombo(host.Config, host.Random)
		end
	end

	spec:ActivateSkill(best.Id)
end

return Attack
