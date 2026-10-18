const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

const Crane = require(ReplicatedStorage.shared.packages.Crane)

const SampleService = Crane:CreateService({
	Name = "SampleService",
})

function SampleService:onStart()
	self.ConfigService = Crane:GetService("ConfigService")
end

return SampleService
