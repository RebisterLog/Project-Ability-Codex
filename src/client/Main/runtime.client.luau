local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Crane = require(ReplicatedStorage.shared.packages.Crane)

Crane:AddServices({ ReplicatedStorage.shared.services, script.Parent.Parent.services })
Crane:AddComponents({ ReplicatedStorage.shared.components, script.Parent.Parent.components })

Crane:Start()
