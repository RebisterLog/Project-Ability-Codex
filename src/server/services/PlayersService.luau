local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerSaveData = require(ReplicatedStorage.shared.schemas.PlayerSaveData)
local Lapis = require(ReplicatedStorage.shared.packages.Lapis)
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local types = require(ServerScriptService.server.types)
local PlayerDynamicData = require(ReplicatedStorage.shared.schemas.PlayerDynamicData)

local PlayersService = Crane:CreateService({
	Name = "PlayersService",
	LoadOrder = 200,
})

function PlayersService.onInit(self: typeof(PlayersService))
	self.Players = {}
	self.Documents = {}
	self.Collection = Lapis.createCollection("PlayerData", {
		defaultData = PlayerSaveData,
	})
end

function PlayersService.onStart(self: typeof(PlayersService))
	Players.PlayerAdded:Connect(function(player)
		local playerComponent = Crane:AddComponent(player, "Player")
		self.Players[player] = playerComponent

		self.Collection:load(`Player{player.UserId}`, { player.UserId })
			:andThen(function(document)
				if player.Parent == nil then
					document:close():catch(warn)
					return
				end

				self.Documents[player] = document

				playerComponent:LoadDocumentData(document:read())
			end)
			:catch(function(message)
				warn(`Player {player.Name}'s data failed to load: {message}`)
				player:Kick("Data failed to load.")
			end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player, reason: Enum.PlayerExitReason)
		local component: types.PlayerComponent = self.Players[player]
		self.Players[player] = nil

		if not component then return end
		if not component.Proxy then return end

		local data = component.Proxy()

		for key, value in PlayerDynamicData do
			data[key] = nil
		end

		Crane:RemoveComponent(player, "Player")

		local document = self.Documents[player]
		document:write(data)

		if document ~= nil then
			self.Documents[player] = nil
			document:close():catch(warn)
		end
	end)

	for i, player in Players:GetPlayers() do
		if self.Players[player] then continue end

		local playerComponent = Crane:AddComponent(player, "Player")
		self.Players[player] = playerComponent

		self.Collection:load(`Player{player.UserId}`, { player.UserId })
			:andThen(function(document)
				if player.Parent == nil then
					document:close():catch(warn)
					return
				end

				self.Documents[player] = document

				playerComponent:LoadDocumentData(document:read())
			end)
			:catch(function(message)
				warn(`Player {player.Name}'s data failed to load: {message}`)
				player:Kick("Data failed to load.")
			end)
	end

	Crane:GetPacket("RequestProxy").listen(function(data: nil, player: Player)
		local component = self.Players[player]
		if not component then return end

		if not component.Proxy then return end

		Crane:GetPacket("RequestProxy").sendTo({
			component.Proxy(),
			Crane:GetService("GameDataService").Proxy(),
		}, player)
	end)
end

function PlayersService:GetPlayer(player: Player)
	return PlayersService.Players[player]
end

return PlayersService
