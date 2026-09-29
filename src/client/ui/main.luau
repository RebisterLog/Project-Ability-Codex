local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Proxy = require(ReplicatedStorage.shared.packages.Proxy)
local PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
local GameData = require(ReplicatedStorage.shared.schemas.GameData)
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Router = require(script.Parent.utils.Router)

local Fusion = require(ReplicatedStorage.shared.packages.Fusion)

local Children = Fusion.Children
local scoped = Fusion.scoped

-- Components
local Button = require(script.Parent.utils.Button)
local Helix = require(script.Parent.utils.Helix)
local PlayerHUD = require(script.Parent.components.PlayerHUD)
local Settings = require(script.Parent.components.Settings)

local scope = scoped(Fusion, {
	Button = Button,
	Helix = Helix,
})

return function(playerProxy: Proxy.ProxyTab<PlayerData.PlayerData>, gameProxy: Proxy.ProxyTab<GameData.GameData>)
	local proxies = {
		PlayerProxy = playerProxy,
		GameProxy = gameProxy,
	}

	local router = Router.new(scope)
	
	router:ProvidePages({
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
		}
	})

	return scope:New "ScreenGui" {
		Name = "Root",

		--IgnoreGuiInset = true,
		Parent = PlayerGui,
		ResetOnSpawn = false,

		[Children] = {
			RootRouter = router:Render("PlayerHUD"),
		}
	}
end