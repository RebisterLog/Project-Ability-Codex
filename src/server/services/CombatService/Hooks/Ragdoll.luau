local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local types = require(ServerScriptService.server.types)
local enums = require(ServerScriptService.server.Enums)

local CombatService = Crane:GetService("CombatService")

return {
	Name = "Ragdoll",
	Type = "Cast",
	Priority = 89,
	Function = function(Data: types.AttackData)
		local State = Data.State
		local Info = Data.Info
		
		if Info.Ragdoll and State.Success and not State.Halt then
			
			local ragdoll = Data.Victim:AddParameter("Ragdoll", true) :: types.ParameterObject<"Ragdoll">

			task.delay(Info.Ragdoll.Duration or 1, ragdoll.Destroy, ragdoll)

			CombatService.Interrupted:Fire(Data.Victim)
		end

		return true
	end,
}