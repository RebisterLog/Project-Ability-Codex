--!native
--!optimize 2

local BotsCharacters = require(game:GetService("ReplicatedStorage").shared["bot-characters"])
local MovementStyles = require(script.Parent.NavigationController.MovementStyles)

--- Posture of the bot: how it stands and how far it keeps from the target.
---
--- This used to be a state machine table, but the states differed only by
--- posture, so telling them apart turned out to be pointless: `Bot` decides who
--- owns the action slot, and the posture is a consequence of that decision.
export type Posture = "Idle" | "Attack" | "Defend"

local DEFEND_DISTANCE = 15

local STYLES: { [Posture]: { Style: string, HoldDistance: number? } } = {
	Idle = { Style = MovementStyles.direct, HoldDistance = nil },
	Attack = { Style = MovementStyles.puma, HoldDistance = nil },
	Defend = { Style = MovementStyles.zigzag, HoldDistance = DEFEND_DISTANCE },
}

local Posture = {}

--- Movement style while attacking: `puma` goes straight in, `zigzag` jukes aside.
---
--- The roll happens on every entry into the attack posture, so bots with a high
--- `Chaotic` vary their manner more often. `Chaotic` in a config is a spread
--- (`0..1`), not a time multiplier: `Aggressive + rand(0, Chaotic)` may exceed
--- one, and that is on purpose.
function Posture.RollAttackStyle(config: BotsCharacters.BotCharacterConfig, random: Random): string
	local chaotic = config.Chaotic

	local isMelee = random:NextNumber() < config.Aggressive + random:NextNumber(0, chaotic)
	if not isMelee then return MovementStyles.puma end

	local isBaiting = random:NextNumber() < config.Agility + random:NextNumber(0, chaotic)

	return if isBaiting then MovementStyles.zigzag else MovementStyles.puma
end

function Posture.Get(name: Posture): { Style: string, HoldDistance: number? }
	return STYLES[name]
end

return Posture
