const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ChargeState = require(ReplicatedStorage.shared.combat.ChargeState)

const Configs = {
	HamonCharge = {
		Default = {
			Amount = 0,
			LastGainAt = 0,
			Filling = false,
			FillStartedAt = 0,
			FillStartAmount = 0,
			Max = 100,
			FillRate = 20,
			DecayRate = 5,
			HoldSeconds = 10,
			DamageMultiplier = 1.25,
		},
	},

	-- Discrete knife charges: always fills, one unit every 5 seconds.
	KnivesCharge = {
		Default = {
			Amount = 3,
			LastGainAt = 0,
			Filling = true,
			FillStartedAt = 0,
			FillStartAmount = 3,
			Max = 3,
			FillRate = 1 / 3,
			DecayRate = 0,
			HoldSeconds = 0,
		},
	},
}

export type ChargeId = "HamonCharge" | "KnivesCharge"
export type State = ChargeState.State

return Configs
