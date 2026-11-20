--!native

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Charge = require(ServerScriptService.server["combat-classes"].Charge)
const Configs = require(ReplicatedStorage.shared.configs.Charges)

export type ChargeId = Configs.ChargeId

const instances: { [string]: Charge.Charge } = {}

for id, config in Configs do
	instances[id] = Charge.new(id, config)
end

const function get(id: ChargeId): Charge.Charge
	const instance = instances[id]
	if not instance then error(`[Charges] Unknown charge "{id}"`, 2) end
	return instance
end

return {
	Get = get,
}
