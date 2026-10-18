const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

const Crane = require(ReplicatedStorage.shared.packages.Crane)

return function(context, players: { Player }, abilityName: string)
	for i, player in players do
		const component = Crane:GetComponent("Player", player)
		if not component then continue end

		const specModule = component:GetModule("SpecModule")

		const id = specModule:GetSpecIdByName(abilityName)

		if not id then return "You don't have this ability, or it doesn't exist" end

		specModule:SetSpec(id)
	end
end
