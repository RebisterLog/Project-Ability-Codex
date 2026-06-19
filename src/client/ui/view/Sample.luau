local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.shared.packages.Fusion)
local OnEvent = require(ReplicatedStorage.shared.packages.Fusion.Instances.OnEvent)
local peek = require(ReplicatedStorage.shared.packages.Fusion.State.peek)

local Children = Fusion.Children
local peek = Fusion.peek
local OnEvent = Fusion.OnEvent
local OnChange = Fusion.OnChange
type UsedAs<T> = Fusion.UsedAs<T>

local function Sample(
	scope: Fusion.Scope,
	props: {
		IsShown: UsedAs<boolean>,
	}
)
	
end

return Sample