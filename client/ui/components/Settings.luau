const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const LocalPlayer = Players.LocalPlayer

const GameData = require(ReplicatedStorage.shared.schemas.GameData)
const PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)
const Router = require(script.Parent.Parent.utils.Router)
const OnEvent = Fusion.OnEvent

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
