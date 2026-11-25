const ReplicatedStorage = game:GetService("ReplicatedStorage")
const StarterPlayer = game:GetService("StarterPlayer")
const TweenService = game:GetService("TweenService")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)
const OnEvent = require(ReplicatedStorage.shared.packages.Fusion.Instances.OnEvent)
const peek = require(ReplicatedStorage.shared.packages.Fusion.State.peek)

const Children = Fusion.Children
const peek = Fusion.peek
const OnEvent = Fusion.OnEvent
const OnChange = Fusion.OnChange
type UsedAs<T> = Fusion.UsedAs<T>

const LoadingString = function(
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
