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

			-- God mode takes the damage out of the humanoid and nothing else: the
			-- multipliers, the indicator and OnTakeDamage still run, so the skills,
			-- the bots and the allies react exactly as they would to a landed hit.
			-- Zeroing Data.Info.Damage instead would hide the indicator and rewrite
			-- the value the caller reads back in its andThen.
			if not Data.Victim:GetParameter("GodMode") then
				Data.Victim.Humanoid:TakeDamage(Data.Info.Damage)
			end

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
