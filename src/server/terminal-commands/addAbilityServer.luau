local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local types = require(ServerScriptService.server.types)

local Crane = require(ReplicatedStorage.shared.packages.Crane)


return function (context, players: {Player}, abilityName: string)
	for i, player in players do
		local component = Crane:GetComponent("Player", player)
		if not component then continue end

		local specModule = component:GetModule("SpecModule")

		local specData: types.SpecSaveData = {
			Id = Crane.Utils.GenerateUUID(),
			Name = abilityName,
			FirstOwnerId = player.UserId,
			ReceivedTime = os.date(),
		}

		specModule:AddSpec(specData)
	end
end