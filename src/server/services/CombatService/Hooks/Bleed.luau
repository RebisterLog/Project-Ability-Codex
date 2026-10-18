const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const types = require(ServerScriptService.server.types)

const VFXService = Crane:GetService("VFXService")

return {
	Name = "Bleed",
	Type = "Cast",
	Priority = 94,
	Function = function(Data: types.AttackData)
		const State = Data.State
		const Info = Data.Info

		if not State.Success then return true end
		if not Info.Bleed then return true end
		if Data.Victim.Humanoid.Health <= 0 then return true end

		const Bleed = Info.Bleed
		const Interval = Bleed.Interval or 0.5

		const bleeding = Data.Victim:AddParameter("Bleeding", {
			Damage = Bleed.Damage,
			Duration = Bleed.Duration,
			Interval = Interval,
			Slow = Bleed.Slow or 8,
		})

		-- The ticks live in the parameter's cleaner instead of their own
		-- scheduled calls: an effect removed early (a cleanse, a dispel) takes
		-- the ticks down with it, so a stale timer can never keep hurting a
		-- target that stopped bleeding. The expiry timer stays outside the
		-- cleaner so that Clean() never cancels the thread it runs on.
		bleeding.Cleaner:Every(Interval, function()
			if not Data.Victim.instance.Parent then return end
			if Data.Victim.Humanoid.Health <= 0 then return end

			local Damage = Bleed.Damage
			Damage *= Data.Attacker:GetParameter("DamageMultiplier")
			Damage *= Data.Victim:GetParameter("DamageReceivalMultiplier")

			Data.Victim.Humanoid:TakeDamage(Damage)

			-- Same shape as Hooks/Damage: a tick is damage like any other, so it
			-- shows an indicator and lets the target's allies react to it.
			if Damage > 0 then
				VFXService:StartEffect(
					Players:GetPlayers(),
					"DamageIndicator",
					Data.Victim.instance,
					Damage,
					"Damage"
				)
			end

			Data.Victim.OnTakeDamage:Fire(Data.Attacker, Data)
		end)

		task.delay(Bleed.Duration or 0, bleeding.Destroy, bleeding)

		return true
	end,
}
