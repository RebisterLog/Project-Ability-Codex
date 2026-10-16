const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const LocalPlayer = Players.LocalPlayer

const GameData = require(ReplicatedStorage.shared.schemas.GameData)
const PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)
const Router = require(script.Parent.Parent.utils.Router)
const OnEvent = Fusion.OnEvent
const peek = Fusion.peek

const Preload = require(script.Preload)

type DefaultProps = {
	PlayerProxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	GameProxy: Proxy.ProxyTab<GameData.GameData>,
}

return function(scope: Fusion.Scope, props: DefaultProps, router: Router.Router)
    const preloadScope = scope:innerScope()

    const preloadedAssets, totalAssets = Preload(preloadScope, function()
        task.wait(3)
        preloadScope:doCleanup()
        router:SwitchPage("PlayerHUD", nil, {
            style = "Transparency",
            duration = 2,
            easingStyle = Enum.EasingStyle.Exponential,
        })
    end)

    const progress = preloadScope:Value(peek(preloadedAssets) / peek(totalAssets))

    preloadScope:Observer(preloadedAssets):onBind(function()
        const value = peek(preloadedAssets) / peek(totalAssets)
        progress:set(value)

        if value >= 1 then
            router:SwitchPage("PlayerHUD")
        end
    end)

    router:SwitchPage("LoadingScreen", {
        Text = "Preloading game assets",
        Progress = progress,
    })
end
