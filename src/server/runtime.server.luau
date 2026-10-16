const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)

Crane:AddServices({ ServerScriptService.server.services, ReplicatedStorage.shared.services })
Crane:AddComponents({ ServerScriptService.server.components, ReplicatedStorage.shared.components })

Crane:Start()
