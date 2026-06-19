local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Proxy = require(ReplicatedStorage.shared.packages.Proxy)
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local types = require(ServerScriptService.server.types)

local SampleModule = {} :: types.PlayerModule

function SampleModule:onInit()
	
end

function SampleModule:onStart()

end

return SampleModule
