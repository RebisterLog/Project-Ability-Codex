const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)
const PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
const GameData = require(ReplicatedStorage.shared.schemas.GameData)

const peek = Fusion.peek

const HamonView = require(script.Parent.Parent.views.HamonView)

type HamonSnapshot = {
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
	ExpiresAt: number,
}

const function getEffective(state: HamonSnapshot, now: number): number
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

return function(
	scope: Fusion.Scope,
	playerProxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	gameProxy: Proxy.ProxyTab<GameData.GameData>
)
	const hamonScope = scope:innerScope()

	const readSnapshot = function(): HamonSnapshot?
		const source = playerProxy()
		if not source or not source.CharacterState then return nil end
		const parameters = source.CharacterState.Parameters
		if not parameters then return nil end
		return parameters.HamonCharge
	end

	const snapshot = hamonScope:Value(readSnapshot())
	const liveAmount = hamonScope:Value(0)

	const updateLive = function()
		const state = peek(snapshot)
		liveAmount:set(if state then getEffective(state, workspace:GetServerTimeNow()) else 0)
	end

	updateLive()

	table.insert(
		hamonScope,
		playerProxy:Subscribe("AnyChange", { "CharacterState", "Parameters" }, function()
			const nextState = readSnapshot()
			if not nextState then return end
			snapshot:set(nextState)
			updateLive()
		end)
	)

	table.insert(hamonScope, RunService.Heartbeat:Connect(updateLive))

	const text = hamonScope:Computed(function(use)
		const state = use(snapshot)
		return ("Hamon: %.1f / %d"):format(use(liveAmount), (if state then state.Max else 100))
	end)

	return HamonView(hamonScope, {
		Text = text,
	})
end
