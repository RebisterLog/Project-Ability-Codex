const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Crane = require(ReplicatedStorage.shared.packages.Crane)

return function(_, targets: { Player }, state: boolean?)
	const changed = {}

	for _, player in targets do
		const component = Crane:GetComponent("Player", player)
		const noCooldown = component and component:GetModule("NoCooldownModule")

		if not noCooldown then continue end

		-- Without an explicit state the toggle follows whoever it was flipped for,
		-- so a mixed selection can end up with some on and some off. The reply
		-- reports per player rather than claiming one outcome for all of them.
		const enabled = if state == nil then not noCooldown:IsEnabled() else state

		noCooldown:Set(enabled)

		table.insert(changed, `{player.Name}: {if enabled then "on" else "off"}`)
	end

	if #changed == 0 then return "No loaded player to change." end

	return `No cooldown — {table.concat(changed, ", ")}`
end
