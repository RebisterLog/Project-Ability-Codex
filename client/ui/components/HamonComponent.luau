const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)
const PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
const GameData = require(ReplicatedStorage.shared.schemas.GameData)
const ChargeState = require(ReplicatedStorage.shared.combat.ChargeState)

const peek = Fusion.peek

const HamonView = require(script.Parent.Parent.views.HamonView)

type HamonSnapshot = ChargeState.Snapshot

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
		liveAmount:set(
			if state then ChargeState.Effective(state, workspace:GetServerTimeNow()) else 0
		)
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
