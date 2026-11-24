--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])
local CombatSnapshot = require(script.Parent.CombatSnapshot)
local SkillIndex = require(script.Parent.SkillIndex)
local SkillPriority = require(script.Parent.SkillPriority)
local types = require(ServerScriptService.server.types)

local DEFAULT_REPEAT_RESET_TIME = 1.5

export type Mode = "normal" | "hold" | "summon"

export type Host = {
	Config: BotsCharacters.BotCharacterConfig,
	Character: types.Character,
	SkillIndex: SkillIndex.SkillIndex,
	Combo: BotsCharacters.SkillCombo,
	ComboIndex: number,
	Repeats: { [string]: { Count: number, At: number } },
	Blocked: { [string]: boolean },
	NavBlocked: boolean,
	DodgeIntent: boolean,
	Random: Random,
}

local Attack = {}

function Attack.RollCombo(
	config: BotsCharacters.BotCharacterConfig,
	random: Random
): BotsCharacters.SkillCombo
	local combos = config.Combos
	if not combos or #combos == 0 then return {} end

	return combos[random:NextInteger(1, #combos)]
end

function Attack.Step(host: Host, mask: number, distance: number, now: number): (string?, Mode?)
	local snapshot = CombatSnapshot:Get(host.Character)
	if snapshot.HasActiveSkills then return nil, nil end

	local combo = host.Combo
	local comboSkillId = combo[host.ComboIndex]
	local candidates =
		host.SkillIndex:Collect(snapshot, now, host.NavBlocked, host.DodgeIntent, distance)
	if #candidates == 0 then
		if host.Config.Debug then print("Bot no candidates") end
		return nil, nil
	end

	table.clear(host.Blocked)

	for id, entry in host.Repeats do
		local options = host.Config.Skills[id]
		local maxRepeats = options and options.MaxRepeats

		if not maxRepeats then
			host.Repeats[id] = nil
			continue
		end

		local resetTime = (options and options.RepeatResetTime) or DEFAULT_REPEAT_RESET_TIME

		if now - entry.At >= resetTime then
			host.Repeats[id] = nil
		elseif entry.Count >= maxRepeats then
			host.Blocked[id] = true
		end
	end

	local best =
		SkillPriority.Select(host.Config, candidates, mask, distance, comboSkillId, host.Blocked)
	if not best then return nil, nil end

	if host.Config.Debug then print("Bot selected skill:", best.Id) end

	local options = host.Config.Skills[best.Id]
	local standState = options and options.StandSummon

	if standState ~= nil then
		if standState and not snapshot.HasStand then return nil, nil end

		if snapshot.StandActive ~= standState then
			if host.Config.Debug then print("Bot summons stand for", best.Id) end
			return best.Id, "summon"
		end
	end

	local maxRepeats = options and options.MaxRepeats
	if maxRepeats then
		local entry = host.Repeats[best.Id]

		if entry then
			entry.Count += 1
			entry.At = now
		else
			host.Repeats[best.Id] = { Count = 1, At = now }
		end
	end

	if comboSkillId == best.Id then
		host.ComboIndex += 1

		if host.ComboIndex > #combo then
			host.ComboIndex = 1
			host.Combo = Attack.RollCombo(host.Config, host.Random)
		end
	end

	local hold = options
		and (options.HoldMaxTime ~= nil or (options.HoldWhile and #options.HoldWhile > 0))

	return best.Id, if hold then "hold" else "normal"
end

return Attack
