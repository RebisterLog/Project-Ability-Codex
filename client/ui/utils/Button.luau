const ReplicatedStorage = game:GetService("ReplicatedStorage")
const TweenService = game:GetService("TweenService")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)

const BTN_TWEEN_INFO = TweenInfo.new(0.1, Enum.EasingStyle.Elastic, Enum.EasingDirection.InOut)
const BTN_ICON_TWEEN_INFO = TweenInfo.new(0.1, Enum.EasingStyle.Elastic, Enum.EasingDirection.InOut)

const getPrettySize = function(origin: UDim2)
	return UDim2.new(origin.X.Scale * 1.1, 0, origin.Y.Scale * 1.1, 0)
end

const cancelAllTweens = function(tweens: { Tween })
	for _, tween in tweens do
		tween:Cancel()
	end
end

const playAllTweens = function(tweens: { Tween })
	for _, tween in tweens do
		tween:Play()
	end
	return tweens
end

const Button = function(scope: Fusion.Scope, button: GuiButton)
	const originalSize = button.Size
	const prettySize = getPrettySize(originalSize)

	const icon = button:FindFirstChild("Icon") :: ImageLabel?
	const originalIconRotation = icon and icon.Rotation

	const tweensInProgress = {}

	const onHover = function()
		const tweens = {
			TweenService:Create(button, BTN_TWEEN_INFO, { Size = prettySize }),
		}

		if icon then
			table.insert(
				tweens,
				TweenService:Create(
					icon,
					BTN_ICON_TWEEN_INFO,
					{ Rotation = originalIconRotation + 15 }
				)
			)
		end

		return tweens
	end

	const onUnhover = function()
		const tweens = {
			TweenService:Create(button, BTN_TWEEN_INFO, { Size = originalSize }),
		}

		if icon then
			table.insert(
				tweens,
				TweenService:Create(icon, BTN_ICON_TWEEN_INFO, { Rotation = originalIconRotation })
			)
		end

		return tweens
	end

	button.MouseEnter:Connect(function()
		cancelAllTweens(tweensInProgress)
		playAllTweens(onHover())
	end)

	button.MouseButton1Up:Connect(function()
		cancelAllTweens(tweensInProgress)
		playAllTweens(onHover())
	end)

	button.MouseLeave:Connect(function()
		cancelAllTweens(tweensInProgress)
		playAllTweens(onUnhover())
	end)

	button.MouseButton1Down:Connect(function()
		cancelAllTweens(tweensInProgress)
		playAllTweens(onUnhover())
	end)

	return button
end

return Button
