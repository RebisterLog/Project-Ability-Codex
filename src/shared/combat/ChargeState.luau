export type State = {
	Amount: number,
	LastGainAt: number,
	Filling: boolean,
	FillStartedAt: number,
	FillStartAmount: number,
	Max: number,
	FillRate: number,
	DecayRate: number,
	HoldSeconds: number,
}

export type Snapshot = State & {
	ExpiresAt: number,
}

const function effective(state: State, now: number): number
	if state.Filling then
		return math.clamp(
			state.FillStartAmount + state.FillRate * (now - state.FillStartedAt),
			0,
			state.Max
		)
	end

	const holdEnd = state.LastGainAt + state.HoldSeconds
	if now <= holdEnd then return math.clamp(state.Amount, 0, state.Max) end

	return math.clamp(state.Amount - state.DecayRate * (now - holdEnd), 0, state.Max)
end

const function expiryAt(state: State): number
	if state.Amount <= 0 or state.Filling or state.DecayRate <= 0 then return 0 end
	return state.LastGainAt + state.HoldSeconds + state.Amount / state.DecayRate
end

const function snapshot(state: State): Snapshot
	const result = table.clone(state) :: Snapshot
	result.ExpiresAt = expiryAt(state)
	return result
end

return {
	Effective = effective,
	ExpiryAt = expiryAt,
	Snapshot = snapshot,
}
