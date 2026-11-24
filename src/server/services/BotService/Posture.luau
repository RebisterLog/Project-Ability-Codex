--!native
--!optimize 2

local BotsCharacters = require(game:GetService("ReplicatedStorage").shared["bot-characters"])
local MovementStyles = require(script.Parent.NavigationController.MovementStyles)

export type Posture = "Idle" | "Attack" | "Defend" | "Charge"

local DEFEND_DISTANCE = 15

local STYLES: { [Posture]: { Style: string, HoldDistance: number? } } = {
	Idle = { Style = MovementStyles.direct, HoldDistance = nil },
	Attack = { Style = MovementStyles.puma, HoldDistance = nil },
	Defend = { Style = MovementStyles.orbit, HoldDistance = DEFEND_DISTANCE },
	Charge = { Style = MovementStyles.direct, HoldDistance = DEFEND_DISTANCE },
}

local Posture = {}

function Posture.RollAttackStyle(config: BotsCharacters.BotCharacterConfig, random: Random): string
	local chaotic = config.Chaotic
	local aggressive = config.Aggressive
	local agility = config.Agility

	local puma = (0.4 + aggressive * 0.8) * (1 + random:NextNumber(0, chaotic))
	local lunge = (0.15 + aggressive * 0.6 + (1 - agility) * 0.2)
		* (1 + random:NextNumber(0, chaotic))
	local zigzag = (0.25 + agility * 0.8) * (1 + random:NextNumber(0, chaotic))
	local sidestep = (0.1 + agility * 0.6) * (1 + random:NextNumber(0, chaotic))
	local flank = (0.1 + agility * 0.3) * (1 + random:NextNumber(0, chaotic))

	local roll = random:NextNumber() * (puma + lunge + zigzag + sidestep + flank)

	if roll < puma then return MovementStyles.puma end
	roll -= puma
	if roll < lunge then return MovementStyles.lunge end
	roll -= lunge
	if roll < zigzag then return MovementStyles.zigzag end
	roll -= zigzag
	if roll < sidestep then return MovementStyles.sidestep end

	return MovementStyles.flank
end

function Posture.RollDefendStyle(config: BotsCharacters.BotCharacterConfig, random: Random): string
	local chaotic = config.Chaotic
	local agility = config.Agility

	local orbit = (0.3 + agility * 0.7) * (1 + random:NextNumber(0, chaotic))
	local strafe = (0.7 - agility * 0.3) * (1 + random:NextNumber(0, chaotic))

	return if random:NextNumber() * (orbit + strafe) < orbit
		then MovementStyles.orbit
		else MovementStyles.strafe
end

function Posture.Get(name: Posture): { Style: string, HoldDistance: number? }
	return STYLES[name]
end

return Posture
