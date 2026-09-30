local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Crane = require(ReplicatedStorage.shared.packages.Crane)

local SampleService = Crane:CreateService({
	Name = "SampleService",
})

function SampleService:onStart()
	self.ConfigService = Crane:GetService("ConfigService")
end

return SampleService
