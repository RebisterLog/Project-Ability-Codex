--!native
--!optimize 2

local BotsCharacters = require(game:GetService("ReplicatedStorage").shared["bot-characters"])
local Crane = require(game:GetService("ReplicatedStorage").shared.packages.Crane)
local Defense = require(script.Parent.Defense)
local SkillPriority = require(script.Parent.SkillPriority)
local types = require(game:GetService("ServerScriptService").server.types)

type Host = {
	Config: BotsCharacters.BotCharacterConfig,
	Character: types.Character,
	Combo: BotsCharacters.SkillCombo,
	ComboIndex: number,
	Random: Random,
}

local CANDIDATES: { types.Skill } = {}

local function CollectCandidates(
	spec: types.Spec,
	config: BotsCharacters.BotCharacterConfig,
	stand: types.Stand?
): { types.Skill }
	table.clear(CANDIDATES)

	for id, skill in spec.Skills do
		if Defense.IsHeldGuard(skill.Data.SkillCharacters) then continue end

		local options = config.Skills[id]
		if not options then continue end

		local valid = skill:Validate()
		local requiredStandState = options.StandSummon
		local isStandActive = stand ~= nil and stand:IsActive()
		local standNeedsToggle = requiredStandState ~= nil
			and isStandActive ~= requiredStandState
			and stand ~= nil

		if not valid and standNeedsToggle then
			valid = not skill.Character:GetParameter("NoSkillCast")
				and skill.Character:GetParameter("Stun").Duration <= 0
				and not skill.Character:GetParameter("Ragdoll")
				and skill.Character.Humanoid.Health > 0
				and not skill:IsOnCooldown()
		end

		if valid then table.insert(CANDIDATES, skill) end
	end

	return CANDIDATES
end

local Attack = {}

function Attack.RollCombo(
	config: BotsCharacters.BotCharacterConfig,
	random: Random
): BotsCharacters.SkillCombo
	local combos = config.Combos
	if not combos or #combos == 0 then return {} end

	return combos[random:NextInteger(1, #combos)]
end

function Attack.Step(host: Host, mask: number, distance: number)
	local spec = host.Character.Spec
	if not spec then return end

	if spec:CheckActiveSkills() then return end

	local combo = host.Combo
	local comboSkillId = combo[host.ComboIndex]
	local stand = Crane:GetService("StandService"):GetStand(host.Character) :: types.Stand?

	local candidates = CollectCandidates(spec, host.Config, stand)
	if #candidates == 0 then
		if host.Config.Debug then print("Bot no candidates") end
		return
	end

	if host.Config.Debug then
		local ids = {}
		for _, c in candidates do
			table.insert(ids, c.Data.Id)
		end
		print("Bot candidates:", table.concat(ids, ", "))
	end

	local best = SkillPriority.Select(host.Config, candidates, mask, distance, comboSkillId)
	if not best then return end

	if host.Config.Debug then print("Bot selected skill:", best.Id) end

	local options = host.Config.Skills[best.Id]
	local requiredStandState = options and options.StandSummon
	if requiredStandState ~= nil then
		local isStandActive = stand ~= nil and stand:IsActive()
		if requiredStandState and not stand then return end

		if isStandActive ~= requiredStandState then
			if host.Config.Debug then print("Bot summons stand for", best.Id) end
			spec:ActivateSkill("Summon")
			return
		end
	end

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
