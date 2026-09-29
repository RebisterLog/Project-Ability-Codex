local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Chrono = require(ReplicatedStorage.shared.packages.chrono)
local Crane = require(ReplicatedStorage.shared.packages.Crane)

local ChronoService = Crane:CreateService({
	Name = "ChronoService",
	LoadOrder = -500,
})

function ChronoService:onStart()
	--Chrono.Start(ReplicatedStorage.shared.configs.Chrono)
end

return ChronoService