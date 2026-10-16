const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const StarterPlayer = game:GetService("StarterPlayer")
const TweenService = game:GetService("TweenService")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Fusion = require(ReplicatedStorage.shared.packages.Fusion)
const GameData = require(ReplicatedStorage.shared.schemas.GameData)
const OnEvent = require(ReplicatedStorage.shared.packages.Fusion.Instances.OnEvent)
const PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)
const RegionView = require(StarterPlayer.StarterPlayerScripts.client.ui.view.RegionView)
const peek = require(ReplicatedStorage.shared.packages.Fusion.State.peek)

const Children = Fusion.Children
const peek = Fusion.peek
const OnEvent = Fusion.OnEvent
const OnChange = Fusion.OnChange
type UsedAs<T> = Fusion.UsedAs<T>

const LocalPlayer = Players.LocalPlayer

--local RunService = game:GetService("RunService")
--local TimeFunction = RunService:IsRunning() and time or os.clock

--local LastIteration, Start
--local FrameUpdateTable = {}

--local function HeartbeatUpdate()
--	LastIteration = TimeFunction()
--	for Index = #FrameUpdateTable, 1, -1 do
--		FrameUpdateTable[Index + 1] = FrameUpdateTable[Index] >= LastIteration - 1 and FrameUpdateTable[Index] or nil
--	end

--	FrameUpdateTable[1] = LastIteration

--	return tostring(math.floor(TimeFunction() - Start >= 1 and #FrameUpdateTable or #FrameUpdateTable / (TimeFunction() - Start)))
--end

--Start = TimeFunction()

const RegionComponent = function(
	scope: Fusion.Scope,
	playerProxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	gameProxy: Proxy.ProxyTab<GameData.GameData>
)
	const regionScope = scope:innerScope()
	const ping = regionScope:Value(60)
	const region = regionScope:Value(gameProxy().ServerRegion)
	const isShown = regionScope:Value(true)

	table.insert(
		regionScope,
		RunService.Heartbeat:Connect(function()
			ping:set(LocalPlayer:GetNetworkPing() * 1000)
		end)
	)

	return RegionView(regionScope, {
		Region = region,
		Ping = ping,
		IsShown = isShown,
	})
end

return RegionComponent
