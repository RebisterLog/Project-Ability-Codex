const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const types = require(ServerScriptService.server.types)

const CombatService = Crane:GetService("CombatService")

const CleanCache = {}

return {
	Name = "Armor",
	Type = "Precast",
	Priority = 88,
	Function = function(Data: types.AttackData)
		const State = Data.State
		const Info = Data.Info

		if State.Armored then
			Info.Ragdoll = nil
			Info.Stun = nil
			Info.Knockback = nil
			Info.Angular = nil

			State.Continue = false
		end

		return true
	end,
}
