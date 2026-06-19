local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local types = require(ServerScriptService.server.types)
local enums = require(ServerScriptService.server.Enums)

local VFXService = Crane:GetService("VFXService")

return {
	Name = "Damage",
	Type = "Cast",
	Priority = 100,
	Function = function(Data: types.AttackData)
		if Data.State.Success and Data.Info.Damage and not Data.State.Halt then

			Data.Info.Damage *= Data.Attacker:GetParameter("DamageMultiplier")
			Data.Info.Damage *= Data.Victim:GetParameter("DamageReceivalMultiplier")

			Data.Victim.Humanoid:TakeDamage(Data.Info.Damage)

			if Data.Info.Damage > 0 then
				VFXService:StartEffect(Players:GetPlayers(), "DamageIndicator", Data.Victim.instance, Data.Info.Damage, "Damage")
			end
			
			Data.Victim.OnTakeDamage:Fire(Data.Attacker, Data)
		end
		return true
	end,
}