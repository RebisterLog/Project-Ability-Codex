local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Proxy = require(ReplicatedStorage.shared.packages.Proxy)
local types = require(ServerScriptService.server.types)

local SampleComponent = Crane:CreateComponent({
	Name = "SampleComponent",
})

function SampleComponent:onStart()
	
end

return SampleComponent