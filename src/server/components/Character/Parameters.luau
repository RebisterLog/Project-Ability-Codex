--!native

const ServerScriptService = game:GetService("ServerScriptService")
const Enums = require(ServerScriptService.server.Enums)

const HighestParser = function(a, b)
	if a < b then return b end
	return a
end
const LowestParser = function(a, b)
	if a < b then return a end
	return b
end
const MultParser = function(a, b)
	return a * b
end
const StunParser = function(a, b)
	if a.Priority < b.Priority then return b end
	return a
end
const ORParser = function(a, b)
	return a or b
end

return {
	Timescale = { Default = 1, Parser = MultParser },
	IFrames = { Default = 0, Parser = HighestParser },
	DamageMultiplier = { Default = 1, Parser = MultParser },
	DamageReceivalMultiplier = { Default = 1, Parser = MultParser },
	HealMultiplier = { Default = 1, Parser = MultParser },
	HealReceivalMultiplier = { Default = 1, Parser = MultParser },
	CooldownMultiplier = { Default = 1, Parser = MultParser },
	MaxWalkSpeed = { Default = 2048, Parser = LowestParser },
	MinWalkSpeed = { Default = 0, Parser = HighestParser },
	MaxJumpPower = { Default = 4096, Parser = LowestParser },

	Stun = {
		Default = {
			Priority = Enums.Stun.None,
			Duration = 0,
		},

		Parser = StunParser,
	},

	Armor = { Default = false, Parser = ORParser },
	Ragdoll = { Default = false, Parser = ORParser },
	NoCollision = { Default = false, Parser = ORParser },
	Restrain = { Default = false, Parser = ORParser },
	NoSkillCast = { Default = false, Parser = ORParser },
}
