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
			DecayRate = 10,
			HoldSeconds = 5,
			DamageMultiplier = 1.25,
		},
	},
}

export type ChargeId = "HamonCharge"
export type State = ChargeState.State

return Configs
