local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local GameData = require(ReplicatedStorage.shared.schemas.GameData)
local PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
local Proxy = require(ReplicatedStorage.shared.packages.Proxy)

local Fusion = require(ReplicatedStorage.shared.packages.Fusion)
local Router = require(script.Parent.Parent.utils.Router)
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

local Preload = require(script.Preload)

type DefaultProps = {
	PlayerProxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	GameProxy: Proxy.ProxyTab<GameData.GameData>,
}

return function(scope: Fusion.Scope, props: DefaultProps, router: Router.Router)
    local preloadScope = scope:innerScope()

    local preloadedAssets, totalAssets = Preload(preloadScope, function()
        task.wait(3)
        preloadScope:doCleanup()
        router:SwitchPage("PlayerHUD", nil, {
            style = "Transparency",
            duration = 2,
            easingStyle = Enum.EasingStyle.Exponential,
        })
    end)

    local progress = preloadScope:Value(peek(preloadedAssets) / peek(totalAssets))

    preloadScope:Observer(preloadedAssets):onBind(function()
        local value = peek(preloadedAssets) / peek(totalAssets)
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
