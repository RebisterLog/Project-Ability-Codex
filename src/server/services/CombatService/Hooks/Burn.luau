--!native
--!optimize 2

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Damage = require(ServerScriptService.server.services.CombatService.Hooks.Damage)
const types = require(ServerScriptService.server.types)

const VFXService = Crane:GetService("VFXService")

--[=[ Burn

   The damage-over-time mirror of `Hooks/Bleed`: `AttackInfo.Burn` carries the
   damage, duration, interval and slowdown of the burn, and the hit puts them on
   the target's `Burning` parameter.

   A tick is damage like any other, so it is paid through `Hooks/Damage` - which
   keeps a `DamageHold` queue and a `NoDeath` debt intact.
]=]

return {
	Name = "Burn",
	Type = "Cast",
	Priority = 94,
	Function = function(Data: types.AttackData)
		const State = Data.State
		const Info = Data.Info

		if not State.Success then return true end
		if not Info.Burn then return true end
		if Data.Victim.Humanoid.Health <= 0 then return true end

		const Burn = Info.Burn
		const Interval = Burn.Interval or 0.5

		const burning = Data.Victim:AddParameter("Burning", {
			Damage = Burn.Damage,
			Duration = Burn.Duration,
			Interval = Interval,
			Slow = Burn.Slow,
		})

		-- The ticks live in the parameter's cleaner, as in `Hooks/Bleed`: a burn
		-- removed from the outside (a cleanse, a dispel) stops ticking with it. The
		-- expiry stays outside the cleaner so that Clean() never cancels the thread
		-- that is running the cleanup.
		burning.Cleaner:Every(Interval, function()
			if not Data.Victim.instance.Parent then return end
			if Data.Victim.Humanoid.Health <= 0 then return end

			local damage = Burn.Damage
			damage *= Data.Attacker:GetParameter("DamageMultiplier")
			damage *= Data.Victim:GetParameter("DamageReceivalMultiplier")

			-- `Damage.Apply` owns the hold bookkeeping: a DamageHold queues the tick
			-- itself, a NoDeath accumulates it as debt. God mode removes the damage,
			-- not the tick.
			if not Data.Victim:GetParameter("GodMode") then
				const debtBefore = Data.Victim.Parameters.NoDeath.Debt or 0
				Damage.Apply(Data.Victim, damage)

				if (Data.Victim.Parameters.NoDeath.Debt or 0) > debtBefore then
					Data.Victim.Parameters.NoDeath.DebtFrom = Data
				end
			end

			if damage > 0 then
				VFXService:StartEffect(Players:GetPlayers(), "DamageIndicator", {
					Character = Data.Victim.instance,
					Amount = damage,
				})
			end

			Data.Victim.OnTakeDamage:Fire(Data.Attacker, Data)
		end)

		task.delay(Burn.Duration, burning.Destroy, burning)

		return true
	end,
}
