local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local types = require(ServerScriptService.server.types)
local enums = require(ServerScriptService.server.Enums)

local CombatService = Crane:GetService("CombatService")

local DefaultBlock = {
	Blockable = true,
	PerfectBlockable = true,
	BlockBreak = false,
	BlockCancel = false,
	BlockIgnore = false,
}

return {
	Name = "Block",
	Type = "Precast",
	Priority = 85,
	Function = function(Data: types.AttackData)
		Data.State.Blocked = false
		Data.State.BlockCanceled = false
		Data.State.BlockBroken = false
		Data.State.PerfectBlocked = false

		if not Data.State.Blocking then
			return true
		end
		
		local Block = Crane.Utils.Reconcile(Data.Info.Block or {}, DefaultBlock)
		
		if Block.BlockIgnore then
			return true
		end
		
		if Block.BlockCancel then
			Data.State.BlockCanceled = true
			return true
		end

		if Data.State.PerfectBlocking and Block.PerfectBlockable then
			Data.State.PerfectBlocked = true
			Data.State.Continue = false
		elseif Block.Blockable then
			Data.State.Blocked = true
			
			if Block.BlockBreak then
				Data.State.BlockBroken = true
			end
		end

		if Data.State.Blocked or Data.State.PerfectBlocked then
			Data.Info.Damage = nil
			Data.Info.Ragdoll = nil
			Data.Info.Stun = nil
			
			Data.Info.Knockback = nil
			Data.Info.Angular = nil
		end

		return true
	end,
}