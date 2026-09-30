local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Fusion = require(ReplicatedStorage.shared.packages.Fusion)
local GameData = require(ReplicatedStorage.shared.schemas.GameData)
local OnEvent = require(ReplicatedStorage.shared.packages.Fusion.Instances.OnEvent)
local PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
local Proxy = require(ReplicatedStorage.shared.packages.Proxy)
local peek = require(ReplicatedStorage.shared.packages.Fusion.State.peek)

local Children = Fusion.Children
local peek = Fusion.peek
local OnEvent = Fusion.OnEvent
local OnChange = Fusion.OnChange
type UsedAs<T> = Fusion.UsedAs<T>

local assets = ReplicatedStorage:QueryDescendants("Animation, Sound, Decal, Texture, GuiObject")

return function(scope, onComplete: () -> ()?): (UsedAs<number>, UsedAs<number>) -- returns (preloadedAssets, totalAssets)
    local totalAssets = scope:Value(0)
    local preloadedAssets = scope:Value(0)

    task.defer(function()
        totalAssets:set(#assets)
        local failed = {}
        
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