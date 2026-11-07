--!native
--!optimize 2

const types = require(game:GetService("ServerScriptService").server.types)

return {
	Name = "Heal",
	Hook = "Heal",
	Type = "Cast",
	Priority = 100,
	Function = function(data: types.HealData)
		if
			not data.State
			or not data.State.Success
			or data.Amount <= 0
			or data.Target.Humanoid.Health <= 0
		then
			return true
		end

		local amount = data.Amount
		if data.Healer then
			amount *= data.Healer:GetParameter("HealMultiplier")
		end
		amount *= data.Target:GetParameter("HealReceivalMultiplier")

		if data.Target:GetParameter("DamageHold") == true then
			table.insert(data.Target.Parameters.DamageHold.Queue, {
				Kind = "Heal",
				Amount = amount,
			})
			return true
		end

		const humanoid = data.Target.Humanoid
		const immediate = math.min(amount, math.max(humanoid.MaxHealth - humanoid.Health, 0))
		if immediate > 0 then
			humanoid.Health += immediate
		end
		return true
	end,
}
