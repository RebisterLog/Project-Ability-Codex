const ReplicatedStorage = game:GetService("ReplicatedStorage")
const StarterPlayer = game:GetService("StarterPlayer")
const TweenService = game:GetService("TweenService")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Fusion = require(ReplicatedStorage.shared.packages.Fusion)
const GameData = require(ReplicatedStorage.shared.schemas.GameData)
const OnEvent = require(ReplicatedStorage.shared.packages.Fusion.Instances.OnEvent)
const PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)
const peek = require(ReplicatedStorage.shared.packages.Fusion.State.peek)

const Children = Fusion.Children
const peek = Fusion.peek
const OnEvent = Fusion.OnEvent
const OnChange = Fusion.OnChange
type UsedAs<T> = Fusion.UsedAs<T>

const Sample = function(
	scope: Fusion.Scope,
	playerProxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	gameProxy: Proxy.ProxyTab<GameData.GameData>
)
end

return Sample
