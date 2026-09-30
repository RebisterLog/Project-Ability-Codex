local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local LocalPlayer = Players.LocalPlayer

local GameData = require(ReplicatedStorage.shared.schemas.GameData)
local LoadingScreen = require(StarterPlayer.StarterPlayerScripts.client.ui.views.LoadingScreen)
local PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
local Proxy = require(ReplicatedStorage.shared.packages.Proxy)
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Router = require(script.Parent.utils.Router)

local Fusion = require(ReplicatedStorage.shared.packages.Fusion)

local Children = Fusion.Children
local scoped = Fusion.scoped
local peek = Fusion.peek
type UsedAs<T> = Fusion.UsedAs<T>

-- Components
local Button = require(script.Parent.utils.Button)
local Helix = require(script.Parent.utils.Helix)
local PlayerHUD = require(script.Parent.components.PlayerHUD)
local PreloadingComponent = require(script.Parent.components.PreloadingComponent)
local Settings = require(script.Parent.components.Settings)
local Shadow = require(script.Parent.utils.Shadow)

local scope = scoped(Fusion, {
	Button = Button,
	Helix = Helix,
	Shadow = Shadow,
})

local Statements = {
	Loading = scope:Value(false),
}

scope.Statements = Statements

return function(
	playerProxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	gameProxy: Proxy.ProxyTab<GameData.GameData>
)
	local proxies = {
		PlayerProxy = playerProxy,
		GameProxy = gameProxy,
	}

	local router = Router.new(scope)

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

			OnEnter = function(pageScope, instance, data: { Text: UsedAs<string>?, Progress: UsedAs<number>? }?)
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
			Page = PlayerHUD(scope, proxies, router),

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
