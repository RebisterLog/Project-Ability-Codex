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
	-- Set by the attack layer when it starts a hold skill (Charge), consumed
	-- by Bot.Tick's release rules.
	HeldSkill: string?,
	HeldAt: number,
	Random: Random,
}

local CANDIDATES: { types.Skill } = {}
local OWNERS: { [string]: types.Spec } = {}

local function CollectCandidates(
	specs: { types.Spec? },
	config: BotsCharacters.BotCharacterConfig,
	stand: types.Stand?
): { types.Skill }
	table.clear(CANDIDATES)
	table.clear(OWNERS)

	for _, spec in specs do
		if not spec then continue end

		for id, skill in spec.Skills do
			if OWNERS[id] then continue end
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

			if valid then
				table.insert(CANDIDATES, skill)
				OWNERS[id] = spec
			end
		end
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
	-- Skills can live in either slot: Standless keeps Block/Dash/Punch, Hamon
	-- keeps the Hamon skills. Both take part in selection.
	const specs = { host.Character.SubSpec, host.Character.Spec }
	if not host.Character.Spec and not host.Character.SubSpec then return end

	-- The action slot is shared by both specs (Character checks both).
	if host.Character:CheckActiveSkills() then return end

	local combo = host.Combo
	local comboSkillId = combo[host.ComboIndex]
	local stand = Crane:GetService("StandService"):GetStand(host.Character) :: types.Stand?

	const candidates = CollectCandidates(specs, host.Config, stand)
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
			const summonSpec = OWNERS.Summon or host.Character.Spec
			if summonSpec then summonSpec:ActivateSkill("Summon") end
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

	-- Hold skills (Charge) yield until DeactivateSkill. Keep the tick free by
	-- spawning the activation and remembering what Bot.Tick must release.
	const hold = options
		and (options.HoldMaxTime ~= nil or (options.HoldWhile and #options.HoldWhile > 0))
	const owner = OWNERS[best.Id] or host.Character.SubSpec or host.Character.Spec

	if hold then
		host.HeldSkill = best.Id
		host.HeldAt = os.clock()

		task.spawn(function()
			if owner then owner:ActivateSkill(best.Id) end
		end)
	else
		if owner then owner:ActivateSkill(best.Id) end
	end
end

return Attack
