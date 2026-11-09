--!native

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

const PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)
const types = require(ServerScriptService.server.types)

const Replication = {}

const parameterNames: { types.ParameterName } = {
	"Stun",
	"Ragdoll",
	"Restrain",
	"MinWalkSpeed",
	"MaxWalkSpeed",
	"MaxJumpPower",
	"HamonCharge",
}

const function serializeParameter(name: types.ParameterName, value: any): any
	if name == "Stun" then
		local expiresAt = 0
		if value.Duration > 0 then expiresAt = workspace:GetServerTimeNow() + value.Duration end

		return {
			Priority = value.Priority,
			ExpiresAt = expiresAt,
		}
	end

	if name == "HamonCharge" then
		-- Ship the timestamps, not a snapshot: the client derives the smooth
		-- value itself (fill/hold/decay) and never needs server ticks.
		local expiresAt = 0
		if value.Amount > 0 and not value.Filling then
			expiresAt = value.LastGainAt + value.HoldSeconds + value.Amount / value.DecayRate
		end

		return {
			Amount = value.Amount,
			LastGainAt = value.LastGainAt,
			Filling = value.Filling,
			FillStartedAt = value.FillStartedAt,
			FillStartAmount = value.FillStartAmount,
			Max = value.Max,
			FillRate = value.FillRate,
			DecayRate = value.DecayRate,
			HoldSeconds = value.HoldSeconds,
			ExpiresAt = expiresAt,
		}
	end

	return value
end

--[=[
	Mirrors the character parameters and the block state into the player proxy.

	Everything published here is best effort: the character can be torn down
	before the player proxy is (`Destroying` fires while `Character.Destroy`
	is still cleaning up, and a player leaving tears the proxy down before the
	rig). A late watcher therefore must never assume the proxy still exists or
	that its `CharacterState` dictionary was not cleared, and a dead character
	must stop publishing instead of indexing the `Parameters` of a destroyed
	component.
]=]
function Replication.Bind(character: types.Character, proxy: Proxy.ProxyTab<PlayerData.PlayerData>)
	local alive = true
	-- The owner can drop the proxy eagerly (the player leaving); the bind keeps
	-- its own reference and reads through it, so the publish path never depends
	-- on a component that is already gone.
	local currentProxy: Proxy.ProxyTab<PlayerData.PlayerData>? = proxy

	const function canPublish(): boolean
		if not alive or not currentProxy then return false end

		const source = currentProxy()
		if not source or not source.CharacterState or not source.CharacterState.Parameters then
			return false
		end

		return character.Cleaner:IsAlive()
	end

	const function publishParameter(name: types.ParameterName)
		if not canPublish() then return end

		const value = character:GetParameter(name)
		if value == nil then return end

		const target = currentProxy :: Proxy.ProxyTab<PlayerData.PlayerData>
		target:Patch({
			{
				Name = "SetDictionary",
				Path = { "CharacterState", "Parameters" },
				Args = { name, serializeParameter(name, value) },
			},
		})
	end

	for _, name in parameterNames do
		if not alive then break end

		const detach = character:WatchParameter(name, function()
			publishParameter(name)
		end)

		-- The cleaner must hold the unsubscribe, not the watcher itself: a
		-- watcher that outlives the component would publish stale values.
		character.Cleaner:Add(detach)
		publishParameter(name)
	end

	const function publishBlocking()
		if not canPublish() then return end

		const target = currentProxy :: Proxy.ProxyTab<PlayerData.PlayerData>
		target:Patch({
			{
				Name = "SetDictionary",
				Path = { "CharacterState" },
				Args = { "Blocking", character.Block.Blocking },
			},
		})
	end

	character.Cleaner:Add(character.Block.Changed:Connect(publishBlocking))
	publishBlocking()

	-- `Destroying` fires before `Character.Destroy`, so the flag is set while
	-- the cleaner still has the watchers; the proxy is dropped at the same
	-- moment so no listener can reach a proxy the player component gave up.
	character.Destroying:Once(function()
		alive = false
		currentProxy = nil
	end)
end

return Replication
