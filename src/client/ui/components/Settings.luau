local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local GameData = require(ReplicatedStorage.shared.schemas.GameData)
local PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
local Proxy = require(ReplicatedStorage.shared.packages.Proxy)

local Fusion = require(ReplicatedStorage.shared.packages.Fusion)
local Router = require(script.Parent.Parent.utils.Router)
local OnEvent = Fusion.OnEvent

type DefaultProps = {
	PlayerProxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	GameProxy: Proxy.ProxyTab<GameData.GameData>,
}

return function(scope: Fusion.Scope, props: DefaultProps, router: Router.Router)
	return scope:New("TextButton")({
		BackgroundColor3 = Color3.fromRGB(255, 0, 0),
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.38, 0.469),
		Size = UDim2.fromScale(0.0521, 0.0926),
		Visible = false,

		[OnEvent("Activated")] = function()
			router:SwitchPage("PlayerHUD", nil, {
				style = "Gallery",
				duration = 0.5,
				easingStyle = Enum.EasingStyle.Sine,
				easingDirection = Enum.EasingDirection.Out,
			})
		end,
	})
end
