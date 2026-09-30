local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local enums = require(ServerScriptService.server.Enums)
local types = require(ServerScriptService.server.types)

local CombatService = Crane:GetService("CombatService")

return {
	Name = "IFrames",
	Type = "Precast",
	Priority = 95,
	Function = function(Data: types.AttackData)
		local Priority = Data.Info.Priority or 0

		if Data.State.IFrames and Data.State.IFrames > Priority then
			Data.State.Success = false
			Data.State.IFrames = nil
		end

		return true
	end,
}
