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