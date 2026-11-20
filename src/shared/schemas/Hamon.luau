export type HamonState = {
	Amount: number,
	LastGainAt: number,
	Filling: boolean,
	FillStartedAt: number,
	FillStartAmount: number,
	Max: number,
	FillRate: number,
	DecayRate: number,
	HoldSeconds: number,
	DamageMultiplier: number,
}

export type HamonSnapshot = HamonState & {
	ExpiresAt: number,
}

const Default: HamonState = {
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
}

const function snapshot(state: HamonState): HamonSnapshot
	const result = table.clone(state) :: HamonSnapshot
	local expiresAt = 0

	if state.Amount > 0 and not state.Filling and state.DecayRate > 0 then
		expiresAt = state.LastGainAt + state.HoldSeconds + state.Amount / state.DecayRate
	end

	result.ExpiresAt = expiresAt
	return result
end

return {
	Default = Default,
	snapshot = snapshot,
}
