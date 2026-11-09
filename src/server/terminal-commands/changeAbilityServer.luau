const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Crane = require(ReplicatedStorage.shared.packages.Crane)

return function(context, players: { Player }, abilityName: string)
	const specService = Crane:GetService("SpecService")

	for i, player in players do
		const component = Crane:GetComponent("Player", player)
		if not component then continue end

		const specModule = component:GetModule("SpecModule")

		const id = specModule:GetSpecIdByName(abilityName)

		if not id then return "You don't have this ability, or it doesn't exist" end

		-- The spec config owns the slot: `SetSpec` rejects a SubSpec, so routing
		-- everything through it would leave the ability unequipped.
		const slot = specService:GetSpecType(abilityName) or "Spec"
		const equipped = if slot == "SubSpec"
			then specModule:SetSubSpec(id)
			else specModule:SetSpec(id)

		if not equipped then return `Failed to equip "{abilityName}" into the "{slot}" slot` end
	end

	return nil
end
