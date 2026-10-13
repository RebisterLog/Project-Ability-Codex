local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Crane = require(ReplicatedStorage.shared.packages.Crane)

local QuestService = Crane:CreateService({
	Name = "QuestService",
})

function QuestService:onStart()
	self.ConfigService = Crane:GetService("ConfigService")
end

return QuestService
