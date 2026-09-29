local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Crane = require(ReplicatedStorage.shared.packages.Crane)

local BotSpawnService = Crane:CreateService({
	Name = "BotSpawnService",
	LoadOrder = 150,
})

function BotSpawnService:onStart()
	self.ConfigService = Crane:GetService("ConfigService")
	
	
end

return BotSpawnService