const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)
const PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)

const peek = Fusion.peek

const AmmoView = require(script.Parent.Parent.views.AmmoView)

return function(
	scope: Fusion.Scope,
	playerProxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	_gameProxy: any
)
	const ammoScope = scope:innerScope()

	const readAmmo = function()
		const source = playerProxy()
		const parameters = source and source.CharacterState and source.CharacterState.Parameters
		return parameters and parameters.Ammo or nil
	end

	const ammo = ammoScope:Value(readAmmo())

	table.insert(
		ammoScope,
		playerProxy:Subscribe("AnyChange", { "CharacterState", "Parameters" }, function()
			ammo:set(readAmmo())
		end)
	)

	const text = ammoScope:Computed(function(use)
		const state = use(ammo)
		const knife = state and state.MarkedKnives
		if knife then return ("Ammo: %d / %d"):format(knife.Amount, knife.Max) end
		return "Ammo: 0 / 0"
	end)

	return AmmoView(ammoScope, { Text = text })
end
