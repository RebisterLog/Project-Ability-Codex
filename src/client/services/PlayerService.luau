const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

const LocalPlayer = Players.LocalPlayer
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const PlayerComponent = require(LocalPlayer.PlayerScripts.client.components.Player)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)

const PlayerService = Crane:CreateService({
	Name = "PlayerService",
	LoadOrder = -10,
})

function PlayerService.onInit(self: typeof(PlayerService))
	self.Player = Crane:AddComponent(Players.LocalPlayer, "Player")

	local proxies = {}

	Crane:GetPacket("RequestProxy").listen(function(data)
		proxies = data
	end)

	while #proxies == 0 do
		Crane:GetPacket("RequestProxy").send()
		task.wait()
	end

	self.Proxy = Proxy(proxies[1])
	self.GameProxy = Proxy(proxies[2])

	Crane:GetPacket("Patch").listen(function(data)
		self.Proxy:Patch(data[1])
		self.GameProxy:Patch(data[2])
	end)
end

function PlayerService.onStart(self: typeof(PlayerService)) end

function PlayerService:GetPlayer()
	return self.Player
end

return PlayerService
