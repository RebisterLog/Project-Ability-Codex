local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

local assets = ReplicatedStorage:QueryDescendants("Animation, Sound, Decal, Texture, GuiObject")
local PreloadedValue = script.Parent.Parent.Preloaded
PreloadedValue.Value = false

local failed = {}
local suscessCount = 0

print(`[Preloading] Preloading {#assets} assets`)

ContentProvider:PreloadAsync(assets, function(content: string, status: Enum.AssetFetchStatus)
	if status == Enum.AssetFetchStatus.Success then
		suscessCount += 1
		return
	end
	
	table.insert(failed, content)
end)

print(`[Preloading] Preloading completed, {suscessCount} assets preloaded`)
print(`[Preloading] Failed to preload {#failed} assets`, failed)

PreloadedValue.Value = true
script:GetActor():SendMessage("PreloadingCompleted", failed)

script:GetActor():Destroy()