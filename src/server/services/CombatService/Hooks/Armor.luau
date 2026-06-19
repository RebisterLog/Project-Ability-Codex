local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local types = require(ServerScriptService.server.types)
local enums = require(ServerScriptService.server.Enums)

local CombatService = Crane:GetService("CombatService")

local CleanCache = {}

return {
	Name = "Armor",
	Type = "Precast",
	Priority = 85,
	Function = function(Data: types.AttackData)
		local State = Data.State
		local Info = Data.Info

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