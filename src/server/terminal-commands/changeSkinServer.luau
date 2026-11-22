const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Crane = require(ReplicatedStorage.shared.packages.Crane)

return function(_context, players: { Player }, specName: string, skinName: string)
	for _, player in players do
		const component = Crane:GetComponent("Player", player)
		if not component then continue end

		const skinModule = component:GetModule("SkinModule")
		const success, reason = skinModule:EquipSkin(specName, skinName)
		if not success then return reason or "Failed to change skin" end
	end

	return nil
end
