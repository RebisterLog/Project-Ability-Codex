local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")

local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Fusion = require(ReplicatedStorage.shared.packages.Fusion)
local GameData = require(ReplicatedStorage.shared.schemas.GameData)
local OnEvent = require(ReplicatedStorage.shared.packages.Fusion.Instances.OnEvent)
local PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
local Proxy = require(ReplicatedStorage.shared.packages.Proxy)
local peek = require(ReplicatedStorage.shared.packages.Fusion.State.peek)

local Children = Fusion.Children
local peek = Fusion.peek
local OnEvent = Fusion.OnEvent
local OnChange = Fusion.OnChange
type UsedAs<T> = Fusion.UsedAs<T>

local function Sample(
	scope: Fusion.Scope,
	playerProxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	gameProxy: Proxy.ProxyTab<GameData.GameData>
)
end

return Sample
