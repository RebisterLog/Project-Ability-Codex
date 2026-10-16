const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

const Crane = require(ReplicatedStorage.shared.packages.Crane)

const QuestService = Crane:CreateService({
	Name = "QuestService",
})

function QuestService:onStart()
	self.ConfigService = Crane:GetService("ConfigService")
end

return QuestService
