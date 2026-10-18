const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const StarterPlayer = game:GetService("StarterPlayer")

const LocalPlayer = Players.LocalPlayer

const GameData = require(ReplicatedStorage.shared.schemas.GameData)
const LoadingScreen = require(StarterPlayer.StarterPlayerScripts.client.ui.views.LoadingScreen)
const PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)
const PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

const Router = require(script.Parent.utils.Router)

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)

const Children = Fusion.Children
const scoped = Fusion.scoped
const peek = Fusion.peek
type UsedAs<T> = Fusion.UsedAs<T>

-- Components
const Button = require(script.Parent.utils.Button)
const Helix = require(script.Parent.utils.Helix)
const PlayerHUDComponent = require(script.Parent.components.PlayerHUDComponent)
const PreloadingComponent = require(script.Parent.components.PreloadingComponent)
const Settings = require(script.Parent.components.Settings)
const Shadow = require(script.Parent.utils.Shadow)

const scope = scoped(Fusion, {
	Button = Button,
	Helix = Helix,
	Shadow = Shadow,
})

const Statements = {
	Loading = scope:Value(false),
}

scope.Statements = Statements

return function(
	playerProxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	gameProxy: Proxy.ProxyTab<GameData.GameData>
)
	const proxies = {
		PlayerProxy = playerProxy,
		GameProxy = gameProxy,
	}

	const router = Router.new(scope)

	router:ProvidePages({
		{
			Name = "LoadingScreen",
			Page = function(pageScope)
				pageScope.Text = pageScope:Value("")
				pageScope.Progress = pageScope:Value(-1)

				return LoadingScreen(pageScope, {
					IsShown = scope.Statements.Loading,
					Text = pageScope.Text,
					Progress = pageScope.Progress,
				})
			end,

			OnEnter = function(
				pageScope,
				instance,
				data: { Text: UsedAs<string>?, Progress: UsedAs<number>? }?
			)
				scope.Statements.Loading:set(true)

				if data and data.Text then
					--pageScope:Observer()
				end

				-- pageScope.Text:set(data.Text)
				-- pageScope.Progress:set(data.Progress)
			end,

			OnLeave = function(pageScope)
				scope.Statements.Loading:set(false)
			end,
		},
		{
			Name = "PlayerHUD",
			Page = PlayerHUDComponent(scope, proxies, router),

			OnEnter = function(scope)
				print("PlayerHUD entered")
			end,

			OnLeave = function(scope)
				print("PlayerHUD left")
			end,
		},

		{
			Name = "Settings",
			Page = Settings(scope, proxies, router),

			OnEnter = function(scope)
				print("Settings entered")
			end,

			OnLeave = function(scope)
				print("Settings left")
			end,
		},
	})

	return scope:New("ScreenGui")({
		Name = "Root",

		IgnoreGuiInset = true,
		Parent = PlayerGui,
		ResetOnSpawn = false,

		[Children] = {
			RootRouter = router:Render("PlayerHUD"),
			PreloadingComponent = PreloadingComponent(scope, proxies, router),
		},
	})
end
