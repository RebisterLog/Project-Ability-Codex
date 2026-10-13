local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local types = require(ServerScriptService.server.types)

local CombatService = Crane:GetService("CombatService")

return {
	Name = "Stun",
	Type = "Cast",
	Priority = 95,
	Function = function(Data: types.AttackData)
		if Data.State.Success and Data.Info.Stun then
			--Data.Info.Stun *= Data.Attacker:GetParameter("StunMultiplier")

			local stun = Data.Victim:AddParameter("Stun", Data.Info.Stun)
			task.delay(Data.Info.Stun.Duration or 0, stun.Destroy, stun)
			CombatService.Interrupted:Fire(Data.Victim)
		end
		return true
	end,
}
