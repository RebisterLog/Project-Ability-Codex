const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const types = require(ServerScriptService.server.types)

const CombatService = Crane:GetService("CombatService")

return {
	Name = "Stun",
	Type = "Cast",
	Priority = 95,
	Function = function(Data: types.AttackData)
		if Data.State.Success and Data.Info.Stun then
			--Data.Info.Stun *= Data.Attacker:GetParameter("StunMultiplier")

			const stun = Data.Victim:AddParameter("Stun", Data.Info.Stun)
			task.delay(Data.Info.Stun.Duration or 0, stun.Destroy, stun)
			CombatService.Interrupted:Fire(Data.Victim)
		end
		return true
	end,
}
