const ReplicatedStorage = game:GetService("ReplicatedStorage")
const PlayerDynamicData = require(ReplicatedStorage.shared.schemas.PlayerDynamicData)
const PlayerSaveData = require(ReplicatedStorage.shared.schemas.PlayerSaveData)

export type PlayerData = PlayerDynamicData.PlayerDynamicData & PlayerSaveData.PlayerSaveData

const data: PlayerData = {}

for i, v in PlayerDynamicData do
	data[i] = v
end

for i, v in PlayerSaveData do
	data[i] = v
end

return data
