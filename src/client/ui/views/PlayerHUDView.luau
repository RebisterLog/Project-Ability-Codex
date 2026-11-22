const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)

const Children = Fusion.Children
type UsedAs<T> = Fusion.UsedAs<T>

const PlayerHUDView = function(
	scope: Fusion.Scope,
	props: {
		DisplayName: UsedAs<string>,
		Level: UsedAs<number>,
		Experience: UsedAs<number>,
		HealthRatio: UsedAs<number>,
		DelayedHealthRatio: UsedAs<number>,
		HealthText: UsedAs<string>,
	}
)
	const healthSpring = scope:Spring(props.HealthRatio, 15)
	const delayedHealthSpring = scope:Spring(props.DelayedHealthRatio, 8)
	const experienceSpring = scope:Spring(props.Experience, 12)

	const healthSize = scope:Computed(function(use)
		return UDim2.fromScale(math.clamp(use(healthSpring), 0, 1), 1)
	end)

	const delayedHealthSize = scope:Computed(function(use)
		return UDim2.fromScale(math.clamp(use(delayedHealthSpring), 0, 1), 1)
	end)

	const experienceSize = scope:Computed(function(use)
		return UDim2.fromScale(math.clamp(use(experienceSpring), 0, 1), 1)
	end)

	const levelText = scope:Computed(function(use)
		return tostring(math.floor(use(props.Level)))
	end)

	return scope:New("Frame")({
		Name = "HUD",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.35, 0.15463),

		[Children] = {
			scope:New("UIAspectRatioConstraint")({
				AspectRatio = 4.02395,
				AspectType = Enum.AspectType.ScaleWithParentSize,
			}),

			scope:New("Frame")({
				Name = "AvatarSlot",
				BackgroundColor3 = Color3.fromRGB(42, 36, 29),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.00744048, 0.0419162),
				Size = UDim2.fromScale(0.212798, 0.844311),
				ZIndex = 2,

				[Children] = {
					scope:New("UIStroke")({
						Name = "AvatarBorder",
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						BorderStrokePosition = Enum.BorderStrokePosition.Inner,
						Color = Color3.new(1, 1, 1),
						LineJoinMode = Enum.LineJoinMode.Miter,
						Thickness = 3,
					}),
				},
			}),

			scope:New("ImageLabel")({
				Name = "Star",
				BackgroundTransparency = 1,
				Image = "rbxassetid://124610969806843",
				Position = UDim2.fromScale(0.190476, 0),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.06, 0.2),
				ZIndex = 4,
			}),

			scope:New("TextLabel")({
				Name = "Name",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/RobotoCondensed.json"),
				Position = UDim2.fromScale(0.24256, 0.0239521),
				Size = UDim2.fromScale(0.708333, 0.236099),
				Text = props.DisplayName,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 4,

				[Children] = {
					scope:New("UITextSizeConstraint")({
						Name = "TextConstraint",
						MaxTextSize = 50,
						MinTextSize = 10,
					}),
				},
			}),

			scope:New("TextLabel")({
				Name = "LevelLabel",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/RobotoCondensed.json"),
				Position = UDim2.fromScale(0.247024, 0.335329),
				Size = UDim2.fromScale(0.0568977, 0.155689),
				Text = "LV.",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 4,

				[Children] = {
					scope:New("UITextSizeConstraint")({
						Name = "TextConstraint",
						MaxTextSize = 50,
						MinTextSize = 6,
					}),
				},
			}),

			scope:New("TextLabel")({
				Name = "LevelValue",
				BackgroundTransparency = 1,
				FontFace = Font.new(
					"rbxasset://fonts/families/RobotoCondensed.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.28869, 0.329341),
				Size = UDim2.fromScale(0.0580356, 0.161676),
				Text = levelText,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 4,

				[Children] = {
					scope:New("UITextSizeConstraint")({
						Name = "TextConstraint",
						MaxTextSize = 50,
						MinTextSize = 8,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "XPTrack",
				BackgroundColor3 = Color3.fromRGB(42, 36, 29),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.346726, 0.359281),
				Size = UDim2.fromScale(0.604167, 0.0419162),
				ZIndex = 3,

				[Children] = {
					scope:New("Frame")({
						Name = "XPFill",
						BackgroundColor3 = Color3.fromRGB(253, 175, 32),
						BorderSizePixel = 0,
						Size = experienceSize,
						ZIndex = 4,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "HPBar",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.245536, 0.610778),
				Size = UDim2.fromScale(0.705357, 0.225074),
				ZIndex = 3,

				[Children] = {
					scope:New("Frame")({
						Name = "HPTrack",
						BackgroundColor3 = Color3.fromRGB(42, 36, 29),
						BorderSizePixel = 0,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 1,
					}),

					scope:New("Frame")({
						Name = "HPDamageBar",
						BackgroundColor3 = Color3.fromRGB(255, 0, 81),
						BorderSizePixel = 0,
						Size = delayedHealthSize,
						ZIndex = 3,
					}),

					scope:New("Frame")({
						Name = "HPFill",
						BackgroundColor3 = Color3.fromRGB(0, 255, 136),
						BorderSizePixel = 0,
						Size = healthSize,
						ZIndex = 4,
					}),

					scope:New("TextLabel")({
						Name = "HPText",
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/RobotoCondensed.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Normal
						),
						Position = UDim2.fromScale(0.0611814, 0.260771),
						Size = UDim2.fromScale(0.421941, 0.464399),
						Text = props.HealthText,
						TextColor3 = Color3.fromRGB(0, 255, 136),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 5,

						[Children] = {
							scope:New("UITextSizeConstraint")({
								Name = "TextConstraint",
								MaxTextSize = 50,
								MinTextSize = 8,
							}),

							scope:New("UIStroke")({
								Name = "HPTextStroke",
								ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
								StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
								Color = Color3.fromRGB(8, 63, 26),
								LineJoinMode = Enum.LineJoinMode.Round,
								Thickness = 0.12,
							}),
						},
					}),
				},
			}),
		},
	})
end

return PlayerHUDView
