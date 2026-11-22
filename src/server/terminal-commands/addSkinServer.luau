const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const types = require(ServerScriptService.server.types)

return function(_context, players: { Player }, specName: string, skinName: string)
	const skins = Crane:GetService("ConfigService"):Get("Skins")[specName]
	if not skins or not skins[skinName] then
		return `Skin "{skinName}" doesn't exist for "{specName}"`
	end

	for _, player in players do
		const component = Crane:GetComponent("Player", player)
		if not component then continue end

		const skinModule = component:GetModule("SkinModule")

		const skinData: types.SkinSaveData = {
			Id = skinName,
			Spec = specName,
			FirstOwnerId = player.UserId,
			ReceivedTime = os.time(),
		}

		skinModule:AddSkin(skinData)
	end

	return nil
end
