const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)

const Children = Fusion.Children

const Background = function(scope: Fusion.Scope)
	return scope:New("Frame")({
		Name = "Background",
		BackgroundColor3 = Color3.fromRGB(27, 42, 53),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),

		[Children] = {
			scope:New("UIGradient")({
				Name = "Gradient",
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(38, 38, 38)),
					ColorSequenceKeypoint.new(0.487889, Color3.new(1, 1, 1)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(38, 38, 38)),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.25625),
					NumberSequenceKeypoint.new(0.479508, 0.7375),
					NumberSequenceKeypoint.new(1, 0.2),
				}),
			}),
		},
	})
end

return Background
