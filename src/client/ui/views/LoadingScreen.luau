local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.shared.packages.Fusion)
local OnEvent = require(ReplicatedStorage.shared.packages.Fusion.Instances.OnEvent)
local peek = require(ReplicatedStorage.shared.packages.Fusion.State.peek)

local Children = Fusion.Children
local peek = Fusion.peek
local OnEvent = Fusion.OnEvent
local OnChange = Fusion.OnChange
type UsedAs<T> = Fusion.UsedAs<T>

local function LoadingString(
	scope: Fusion.Scope,
	props: {
		IsShown: UsedAs<boolean>,
		Text: UsedAs<string>?,
		Progress: UsedAs<number>?,
	}
)
	return scope:New("Frame")({
		--Visible = props.IsShown,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,

		[Children] = {
			scope:New("ImageLabel")({
				Name = "Photo",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(18, 18, 18),
				BorderColor3 = Color3.new(),
				BorderSizePixel = 0,
				Image = "rbxassetid://115647499263818",
				Position = UDim2.fromScale(0.5, 0.5),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(1, 1),
				ZIndex = -2,
			}),

			scope:Helix({
				Position = UDim2.fromScale(0.9, 0.9),
				Size = UDim2.fromOffset(100, 100),
			}),
		},
	})
end

return LoadingString
