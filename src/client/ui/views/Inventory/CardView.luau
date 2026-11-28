const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)

const Children = Fusion.Children
const OnEvent = Fusion.OnEvent
type UsedAs<T> = Fusion.UsedAs<T>

const CardView = function(
	scope: Fusion.Scope,
	props: {
		Name: UsedAs<string>,
		Icon: UsedAs<string>,
		RarityColor: UsedAs<Color3>,
		Equipped: UsedAs<boolean>,
		Selected: UsedAs<boolean>,
		OnClick: () -> (),
	}
)
	const iconVisible = scope:Computed(function(use)
		return use(props.Icon) ~= ""
	end)

	const strokeColor = scope:Computed(function(use)
		return if use(props.Selected) or use(props.Equipped)
			then Color3.fromRGB(0, 230, 118)
			else use(props.RarityColor)
	end)

	return scope:Button(scope:New("ImageButton")({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(42, 36, 29),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Image = props.Icon,
		Position = UDim2.fromScale(0.5, 0.5),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(0.161, 0.146),

		[OnEvent("MouseButton1Click")] = function()
			props.OnClick()
		end,

		[Children] = {
			scope:New("UIStroke")({
				Name = "Rarity",
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = strokeColor,
				Thickness = 2,
			}),

			scope:New("UICorner")({
				Name = "Corner",
				CornerRadius = UDim.new(0.01, 2),
			}),

			scope:New("TextLabel")({
				Name = "Placeholder",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/RobotoCondensed.json"),
				Position = UDim2.fromScale(0.5, 0.41),
				Size = UDim2.fromScale(0.8, 0.1),
				Text = "TEMPLATE",
				TextColor3 = Color3.fromRGB(150, 160, 170),
				TextScaled = true,
				Visible = scope:Computed(function(use)
					return not use(iconVisible)
				end),

				[Children] = {
					scope:New("UITextSizeConstraint")({
						Name = "TextSizeCap",
						MaxTextSize = 18,
					}),
				},
			}),

			scope:New("TextLabel")({
				Name = "Name",
				BackgroundColor3 = Color3.fromRGB(42, 36, 29),
				BackgroundTransparency = 0.15,
				FontFace = Font.new("rbxasset://fonts/families/RobotoCondensed.json"),
				Position = UDim2.fromScale(0.06, 0.82),
				Size = UDim2.fromScale(0.88, 0.16),
				Text = props.Name,
				TextColor3 = Color3.fromRGB(232, 232, 232),
				TextScaled = true,

				[Children] = {
					scope:New("UITextSizeConstraint")({
						Name = "TextSizeCap",
						MaxTextSize = 22,
					}),
				},
			}),
		},
	}))
end

return CardView
