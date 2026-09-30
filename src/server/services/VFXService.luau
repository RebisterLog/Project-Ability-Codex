local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local SpecClass = require(ServerScriptService.server["combat-classes"].Spec)
local Specs = require(ReplicatedStorage.shared.configs.Specs)
local types = require(ServerScriptService.server.types)

local VFXService = Crane:CreateService({
	Name = "VFXService",
})

function VFXService:onStart()
	self.StartEffectPacket = Crane:GetPacket("StartVFX")
	self.StopEffectPacket = Crane:GetPacket("StopVFX")
end

-- Accepts Players and their models
function VFXService:StartEffect(players: { Player | Model }, name: string, ...)
	for i, player in players do
		if player:IsA("Model") then player = Players:GetPlayerFromCharacter(player) end
		if not player then continue end

		self.StartEffectPacket.sendTo({
			name = name,
			args = { ... },
		}, player)
	end
end

function VFXService:StartEffectExcept(players: { Player | Model }, name: string, ...)
	for i, player in Players:GetPlayers() do
		if table.find(players, player) then continue end

		self.StartEffectPacket.sendTo({
			name = name,
			args = { ... },
		}, player)
	end
end

function VFXService:StopEffect(players: { Player | Model }, name: string, ...)
	for i, player in players do
		if player:IsA("Model") then player = game.Players:GetPlayerFromCharacter(player) end
		if not player then continue end

		self.StopEffectPacket.sendTo({
			name = name,
			args = { ... },
		}, player)
	end
end

function VFXService:StopEffectExcept(players: { Player }, name: string, ...)
	for i, player in Players:GetPlayers() do
		if table.find(players, player) then continue end

		self.StopEffectPacket.sendTo({
			name = name,
			args = { ... },
		}, player)
	end
end

return VFXService
