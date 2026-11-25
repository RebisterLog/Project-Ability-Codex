const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const LocalPlayer = Players.LocalPlayer
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const PlayerComponent = require(LocalPlayer.PlayerScripts.client.components.Player)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)
const PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
const GameData = require(ReplicatedStorage.shared.schemas.GameData)

export type ClientPlayerModule = {
	Name: string,
	player: typeof(PlayerComponent),
	playerProxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	gameProxy: Proxy.ProxyTab<GameData.GameData>,
	Cleaner: typeof(Crane.Buttler.new()),
	onInit: ((self: ClientPlayerModule) -> ())?,
	onStart: ((self: ClientPlayerModule) -> ())?,
	onCharacter: ((self: ClientPlayerModule, character: Model) -> ())?,
	onDestroy: ((self: ClientPlayerModule) -> ())?,
}

return nil
