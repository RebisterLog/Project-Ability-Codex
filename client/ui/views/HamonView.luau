const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)

const Children = Fusion.Children
type UsedAs<T> = Fusion.UsedAs<T>

return function(
	scope: Fusion.Scope,
	props: {
		Text: UsedAs<string>,
	}
)
	return scope:New("Frame")({
		Name = "HamonDebug",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.fromRGB(24, 24, 28),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(220, 44),

		[Children] = {
			scope:New("UICorner")({
				CornerRadius = UDim.new(0, 6),
			}),
			scope:New("UIStroke")({
				Color = Color3.fromRGB(255, 215, 100),
				Thickness = 1,
			}),
			scope:New("TextLabel")({
				Name = "HamonText",
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Size = UDim2.fromScale(1, 1),
				Text = props.Text,
				TextColor3 = Color3.fromRGB(255, 235, 175),
				TextSize = 20,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		},
	})
end
