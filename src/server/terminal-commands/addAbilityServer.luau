const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const types = require(ServerScriptService.server.types)

const Crane = require(ReplicatedStorage.shared.packages.Crane)

return function(context, players: { Player }, abilityName: string)
	for i, player in players do
		const component = Crane:GetComponent("Player", player)
		if not component then continue end

		const specModule = component:GetModule("SpecModule")

		const specData: types.SpecSaveData = {
			Id = Crane.Utils.GenerateUUID(),
			Name = abilityName,
			FirstOwnerId = player.UserId,
			ReceivedTime = os.date(),
		}

		specModule:AddSpec(specData)
	end
end
