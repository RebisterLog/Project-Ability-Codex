const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const types = require(ServerScriptService.server.types)

const VFXService = Crane:GetService("VFXService")

return {
	Name = "Damage",
	Type = "Cast",
	Priority = 100,
	Function = function(Data: types.AttackData)
		if Data.State.Success and Data.Info.Damage and Data.Victim.Humanoid.Health > 0 then
			Data.Info.Damage *= Data.Attacker:GetParameter("DamageMultiplier")
			Data.Info.Damage *= Data.Victim:GetParameter("DamageReceivalMultiplier")

			Data.Victim.Humanoid:TakeDamage(Data.Info.Damage)

			if Data.Info.Damage > 0 then
				VFXService:StartEffect(
					Players:GetPlayers(),
					"DamageIndicator",
					Data.Victim.instance,
					Data.Info.Damage,
					"Damage"
				)
			end

			Data.Victim.OnTakeDamage:Fire(Data.Attacker, Data)
		end
		return true
	end,
}
