const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)
const ChargeState = require(ReplicatedStorage.shared.combat.ChargeState)
const PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)

const peek = Fusion.peek

const AmmoView = require(script.Parent.Parent.views.AmmoView)

return function(
	scope: Fusion.Scope,
	playerProxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	_gameProxy: any
)
	const ammoScope = scope:innerScope()

	const readCharge = function()
		const source = playerProxy()
		const parameters = source and source.CharacterState and source.CharacterState.Parameters
		return parameters and parameters.KnivesCharge or nil
	end

	const snapshot = ammoScope:Value(readCharge())
	const liveAmount = ammoScope:Value(0)

	const updateLive = function()
		const state = peek(snapshot)
		liveAmount:set(
			if state
				then math.floor(ChargeState.Effective(state, workspace:GetServerTimeNow()))
				else 0
		)
	end

	updateLive()

	table.insert(
		ammoScope,
		playerProxy:Subscribe("AnyChange", { "CharacterState", "Parameters" }, function()
			const nextState = readCharge()
			if not nextState then return end
			snapshot:set(nextState)
			updateLive()
		end)
	)
	table.insert(ammoScope, RunService.Heartbeat:Connect(updateLive))

	const text = ammoScope:Computed(function(use)
		const state = use(snapshot)
		return ("Knives: %d / %d"):format(use(liveAmount), if state then state.Max else 3)
	end)

	return AmmoView(ammoScope, { Text = text })
end
