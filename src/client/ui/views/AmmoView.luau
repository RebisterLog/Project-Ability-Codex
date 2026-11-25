const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)

const Children = Fusion.Children
type UsedAs<T> = Fusion.UsedAs<T>

return function(scope: Fusion.Scope, props: { Text: UsedAs<string> })
	return scope:New("Frame")({
		Name = "AmmoDebug",
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = Color3.fromRGB(24, 24, 28),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(220, 44),

		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
			scope:New("UIStroke")({
				Color = Color3.fromRGB(140, 200, 255),
				Thickness = 1,
			}),
			scope:New("TextLabel")({
				Name = "AmmoText",
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Size = UDim2.fromScale(1, 1),
				Text = props.Text,
				TextColor3 = Color3.fromRGB(220, 240, 255),
				TextSize = 20,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		},
	})
end
