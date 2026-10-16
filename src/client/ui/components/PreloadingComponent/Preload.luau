const ContentProvider = game:GetService("ContentProvider")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

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

const assets = ReplicatedStorage:QueryDescendants("Animation, Sound, Decal, Texture, GuiObject")

return function(scope, onComplete: () -> ()?): (UsedAs<number>, UsedAs<number>) -- returns (preloadedAssets, totalAssets)
    const totalAssets = scope:Value(0)
    const preloadedAssets = scope:Value(0)

    task.defer(function()
        totalAssets:set(#assets)
        const failed = {}
        
        print(`[Preloading] Preloading {#assets} assets`)
        
        ContentProvider:PreloadAsync(assets, function(content: string, status: Enum.AssetFetchStatus)
        	if status == Enum.AssetFetchStatus.Success then
        		preloadedAssets:set(peek(preloadedAssets) + 1)
        		return
        	end
            
        	table.insert(failed, content)
        end)
        
        print(`[Preloading] Preloading completed, {peek(preloadedAssets)} assets preloaded`)
        print(`[Preloading] Failed to preload {#failed} assets`, failed)

        if onComplete then
            onComplete(peek(preloadedAssets), peek(totalAssets))
        end
    end)

    return preloadedAssets, totalAssets
end