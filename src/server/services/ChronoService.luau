local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local types = require(ServerScriptService.server.types)

local Chrono = require(ReplicatedStorage.shared.packages.chrono)
local Crane = require(ReplicatedStorage.shared.packages.Crane)

local ChronoService = Crane:CreateService({
	Name = "ChronoService",
	LoadOrder = -500,
})

function ChronoService:onStart()
	--Chrono.Start(ReplicatedStorage.shared.configs.Chrono)
end

function ChronoService:RegisterNPC(name: string, character: types.Character)
	local npc = Chrono.Entity.new(name, character.instance)
end

return ChronoService