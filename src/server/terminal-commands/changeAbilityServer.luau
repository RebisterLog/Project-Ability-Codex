local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Crane = require(ReplicatedStorage.shared.packages.Crane)

return function(context, players: { Player }, abilityName: string)
	for i, player in players do
		local component = Crane:GetComponent("Player", player)
		if not component then continue end

		local specModule = component:GetModule("SpecModule")

		local id = specModule:GetSpecIdByName(abilityName)

		if not id then return "You don't have this ability, or it doesn't exist" end

		specModule:SetSpec(id)
	end
end
