const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const SpecClass = require(ServerScriptService.server["combat-classes"].Spec)
const Specs = require(ReplicatedStorage.shared.configs.Specs)
const types = require(ServerScriptService.server.types)

const VFXService = Crane:CreateService({
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
