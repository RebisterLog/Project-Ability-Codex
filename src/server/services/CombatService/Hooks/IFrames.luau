const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const types = require(ServerScriptService.server.types)

const CombatService = Crane:GetService("CombatService")

return {
	Name = "IFrames",
	Type = "Precast",
	Priority = 95,
	Function = function(Data: types.AttackData)
		const Priority = Data.Info.Priority or 0

		if Data.State.IFrames and Data.State.IFrames > Priority then
			Data.State.Success = false
			Data.State.IFrames = nil
		end

		return true
	end,
}
