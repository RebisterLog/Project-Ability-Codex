local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDynamicData = require(ReplicatedStorage.shared.schemas.PlayerDynamicData)
local PlayerSaveData = require(ReplicatedStorage.shared.schemas.PlayerSaveData)

export type PlayerData = PlayerDynamicData.PlayerDynamicData & PlayerSaveData.PlayerSaveData

local data: PlayerData = {}

for i, v in PlayerDynamicData do
	data[i] = v
end

for i, v in PlayerSaveData do
	data[i] = v
end

return data
