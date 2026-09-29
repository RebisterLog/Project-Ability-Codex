local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)

Crane:AddServices({ServerScriptService.server.services, ReplicatedStorage.shared.services})
Crane:AddComponents({ServerScriptService.server.components, ReplicatedStorage.shared.components})

Crane:Start()
