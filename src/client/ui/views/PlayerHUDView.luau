const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)

const Children = Fusion.Children
type UsedAs<T> = Fusion.UsedAs<T>

const PlayerHUDView = function(
	scope: Fusion.Scope,
	props: {
		HealthRatio: UsedAs<number>,
		HealthText: UsedAs<string>,
		LevelText: UsedAs<string>,
		Experience: UsedAs<number>,
		DisplayName: UsedAs<string>,
		AvatarImage: UsedAs<string>,
		TopInsetScale: UsedAs<number>,
	}
)
	const healthSpring = scope:Spring(props.HealthRatio, 25)
	const experienceSpring = scope:Spring(props.Experience, 20)

	const sweepAngle = scope:Computed(function(use)
		return use(experienceSpring) * 360
	end)

	const bottomRotation = scope:Computed(function(use)
		return math.min(use(sweepAngle) - 270, -90)
	end)

	const topRotation = scope:Computed(function(use)
		return use(sweepAngle) - 270
	end)

	const isBottomShown = scope:Computed(function(use)
		return use(sweepAngle) > 0.5
	end)

	const isTopShown = scope:Computed(function(use)
		return use(sweepAngle) > 182
	end)

	return scope:New("Frame")({
		Name = "PlayerHUD",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = scope:Computed(function(use)
			return UDim2.fromScale(0, use(props.TopInsetScale))
		end),
		Size = UDim2.fromScale(0.276172, 0.147222),

		[Children] = {
			scope:New("Frame")({
				Name = "Panel",
				BackgroundColor3 = Color3.fromRGB(40, 61, 93),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.123055, 0.471698),
				Size = UDim2.fromScale(0.876945, 0.353774),
				ZIndex = 1,

				[Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0, 5),
					}),
					scope:New("UIStroke")({
						BorderStrokePosition = Enum.BorderStrokePosition.Inner,
						Color = Color3.fromRGB(207, 81, 100),
						Thickness = 4,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "BarBackground",
				BackgroundColor3 = Color3.fromRGB(60, 24, 29),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.247525, 0.519623),
				Size = UDim2.fromScale(0.742574, 0.254717),
				ZIndex = 2,

				[Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0, 5),
					}),
					scope:New("UIStroke")({
						BorderStrokePosition = Enum.BorderStrokePosition.Inner,
						Color = Color3.fromRGB(207, 81, 100),
						Thickness = 4,
					}),

					scope:New("Frame")({
						Name = "BarFill",
						BackgroundColor3 = Color3.fromRGB(207, 81, 100),
						BorderSizePixel = 0,
						Size = scope:Computed(function(use)
							return UDim2.fromScale(use(healthSpring), 1)
						end),
						ZIndex = 3,

						[Children] = {
							scope:New("UICorner")({
								CornerRadius = UDim.new(0, 5),
							}),
						},
					}),

					scope:New("TextLabel")({
						Name = "HealthText",
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						FontFace = Font.new(
							"rbxasset://fonts/families/Balthazar.json",
							Enum.FontWeight.Regular,
							Enum.FontStyle.Normal
						),
						Size = UDim2.fromScale(1, 1),
						Text = props.HealthText,
						TextColor3 = Color3.fromRGB(207, 81, 100),
						TextSize = 48,
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
						ZIndex = 4,

						[Children] = {
							scope:New("UIStroke")({
								Color = Color3.fromRGB(60, 24, 29),
								Thickness = 2,
							}),
						},
					}),
				},
			}),

			scope:New("Frame")({
				Name = "AvatarBackground",
				BackgroundColor3 = Color3.fromRGB(89, 83, 65),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(0.247525, 0.825472),
				ZIndex = 5,

				[Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0.5, 0),
					}),
				},
			}),

			scope:New("Frame")({
				Name = "SweepTop",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Size = UDim2.fromScale(0.247525, 0.412736),
				Visible = isTopShown,
				ZIndex = 6,

				[Children] = {
					scope:New("ImageLabel")({
						Name = "Sweep",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Image = "rbxassetid://93461507310089",
						Position = UDim2.fromScale(0.5, 1),
						Rotation = topRotation,
						Size = UDim2.fromScale(1, 2),
					}),
				},
			}),

			scope:New("Frame")({
				Name = "SweepBottom",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Position = UDim2.fromScale(0, 0.412736),
				Size = UDim2.fromScale(0.247525, 0.412736),
				Visible = isBottomShown,
				ZIndex = 6,

				[Children] = {
					scope:New("ImageLabel")({
						Name = "Sweep",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Image = "rbxassetid://93461507310089",
						Position = UDim2.fromScale(0.5, 0),
						Rotation = bottomRotation,
						Size = UDim2.fromScale(1, 2),
					}),
				},
			}),

			scope:New("ImageLabel")({
				Name = "AvatarPhoto",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = props.AvatarImage,
				Position = UDim2.fromScale(0.016973, 0.056604),
				Size = UDim2.fromScale(0.213579, 0.707547),
				ZIndex = 7,

				[Children] = {
					scope:New("UICorner")({
						CornerRadius = UDim.new(0.5, 0),
					}),
				},
			}),

			scope:New("TextLabel")({
				Name = "Nickname",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = Font.new(
					"rbxasset://fonts/families/Balthazar.json",
					Enum.FontWeight.Regular,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.251768, 0.231132),
				Size = UDim2.fromScale(0.528996, 0.245283),
				Text = props.DisplayName,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 40,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 8,

				[Children] = {
					scope:New("UIStroke")({
						Color = Color3.fromRGB(0, 0, 0),
						Thickness = 2,
					}),
				},
			}),

			scope:New("TextLabel")({
				Name = "Level",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				FontFace = Font.new(
					"rbxasset://fonts/families/Balthazar.json",
					Enum.FontWeight.Regular,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.123762, 0.830189),
				Size = UDim2.fromScale(0.247525, 0.221698),
				Text = props.LevelText,
				TextColor3 = Color3.fromRGB(255, 235, 175),
				TextSize = 36,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = 9,
			}),
		},
	})
end

return PlayerHUDView
