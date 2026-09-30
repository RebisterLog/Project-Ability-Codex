local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.shared.packages.Fusion)

local BTN_TWEEN_INFO = TweenInfo.new(0.1, Enum.EasingStyle.Elastic, Enum.EasingDirection.InOut)
local BTN_ICON_TWEEN_INFO = TweenInfo.new(0.1, Enum.EasingStyle.Elastic, Enum.EasingDirection.InOut)

local function getPrettySize(origin: UDim2)
	return UDim2.new(origin.X.Scale * 1.1, 0, origin.Y.Scale * 1.1, 0)
end

local function cancelAllTweens(tweens: { Tween })
	for _, tween in tweens do
		tween:Cancel()
	end
end

local function playAllTweens(tweens: { Tween })
	for _, tween in tweens do
		tween:Play()
	end
	return tweens
end

local function Button(scope: Fusion.Scope, button: GuiButton)
	local originalSize = button.Size
	local prettySize = getPrettySize(originalSize)

	local icon = button:FindFirstChild("Icon") :: ImageLabel?
	local originalIconRotation = icon and icon.Rotation

	local tweensInProgress = {}

	local function onHover()
		local tweens = {
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

	local function onUnhover()
		local tweens = {
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
