const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

const Crane = require(ReplicatedStorage.shared.packages.Crane)

const BotSpawnService = Crane:CreateService({
	Name = "BotSpawnService",
	LoadOrder = 150,
})

function BotSpawnService:onStart()
	self.ConfigService = Crane:GetService("ConfigService")
end

return BotSpawnService
