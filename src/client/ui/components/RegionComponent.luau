local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.shared.packages.Fusion)
local OnEvent = require(ReplicatedStorage.shared.packages.Fusion.Instances.OnEvent)
local peek = require(ReplicatedStorage.shared.packages.Fusion.State.peek)
local Proxy = require(ReplicatedStorage.shared.packages.Proxy)
local GameData = require(ReplicatedStorage.shared.schemas.GameData)
local PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local RegionView = require(StarterPlayer.StarterPlayerScripts.client.ui.view.RegionView)

local Children = Fusion.Children
local peek = Fusion.peek
local OnEvent = Fusion.OnEvent
local OnChange = Fusion.OnChange
type UsedAs<T> = Fusion.UsedAs<T>

local LocalPlayer = Players.LocalPlayer

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

local function RegionComponent(
	scope: Fusion.Scope,
	playerProxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	gameProxy: Proxy.ProxyTab<GameData.GameData>
)
	local regionScope = scope:innerScope()
	local ping = regionScope:Value(60)
	local region = regionScope:Value(gameProxy().ServerRegion)
	local isShown = regionScope:Value(true)
	
	table.insert(regionScope, RunService.Heartbeat:Connect(function()
		ping:set(LocalPlayer:GetNetworkPing() * 1000)
	end))

	return RegionView(regionScope, {
		Region =  region,
		Ping = ping,
		IsShown = isShown,
	})
end

return RegionComponent