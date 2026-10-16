const TweenService = game:GetService("TweenService")

const SwitchStyle = {
	Visibility = "Visibility",
	Transparency = "Transparency",
	CardsUp = "CardsUp",
	CardsDown = "CardsDown",
	Gallery = "Gallery",
}

export type SwitchStyle = keyof<typeof(SwitchStyle)>

const CreateInfo = function(props): TweenInfo
	return TweenInfo.new(
		props.duration or 0.25,
		props.easingStyle or Enum.EasingStyle.Linear,
		props.easingDirection or Enum.EasingDirection.Out,
		props.repeatCount or 0,
		props.reverses or false,
		props.delay or 0
	)
end

return {
	SwitchStyle = SwitchStyle,

	Animations = {
		[SwitchStyle.Transparency] = {
			Enter = function(canvas: CanvasGroup, props)
				canvas.GroupTransparency = 1
				canvas.Visible = true

				const tween =
					TweenService:Create(canvas, CreateInfo(props), { GroupTransparency = 0 })

				tween:Play()

				return tween
			end,

			Leave = function(canvas: CanvasGroup, props)
				const tween =
					TweenService:Create(canvas, CreateInfo(props), { GroupTransparency = 1 })

				tween.Completed:Once(function()
					canvas.Visible = false
					canvas.GroupTransparency = 0
				end)

				tween:Play()

				return tween
			end,
		},

		[SwitchStyle.Visibility] = {
			Enter = function(canvas: CanvasGroup)
				canvas.Visible = true
			end,

			Leave = function(canvas: CanvasGroup)
				canvas.Visible = false
			end,
		},

		[SwitchStyle.CardsUp] = {
			Enter = function(canvas: CanvasGroup, props)
				canvas.Position = UDim2.fromScale(0.5, -1.5)
				canvas.GroupTransparency = 0
				canvas.Visible = true

				const tween = TweenService:Create(
					canvas,
					CreateInfo(props),
					{ Position = UDim2.fromScale(0.5, 0.5) }
				)
				tween:Play()

				return function()
					tween:Cancel()
				end
			end,

			Leave = function(canvas: CanvasGroup, props)
				const tween = TweenService:Create(
					canvas,
					CreateInfo(props),
					{ Position = UDim2.fromScale(0.5, -1.5) }
				)

				tween.Completed:Once(function()
					canvas.Position = UDim2.fromScale(0.5, 0.5)
					canvas.GroupTransparency = 0
					canvas.Visible = false
				end)

				tween:Play()

				return function()
					tween:Cancel()
				end
			end,
		},

		[SwitchStyle.CardsDown] = {
			Enter = function(canvas: CanvasGroup, props)
				canvas.Position = UDim2.fromScale(0.5, 1.5)
				canvas.GroupTransparency = 0
				canvas.Visible = true

				const tween = TweenService:Create(
					canvas,
					CreateInfo(props),
					{ Position = UDim2.fromScale(0.5, 0.5) }
				)
				tween:Play()

				return function()
					tween:Cancel()
				end
			end,

			Leave = function(canvas: CanvasGroup, props)
				const tween = TweenService:Create(
					canvas,
					CreateInfo(props),
					{ Position = UDim2.fromScale(0.5, 1.5) }
				)

				tween.Completed:Once(function()
					canvas.GroupTransparency = 0
					canvas.Visible = false
					canvas.Position = UDim2.fromScale(0.5, 0.5)
				end)

				tween:Play()

				return function()
					tween:Cancel()
				end
			end,
		},

		[SwitchStyle.Gallery] = {
			Enter = function(canvas: CanvasGroup, props)
				canvas.Position = UDim2.fromScale(1.5, 0.5)
				canvas.GroupTransparency = 0
				canvas.Visible = true

				const tween = TweenService:Create(
					canvas,
					CreateInfo(props),
					{ Position = UDim2.fromScale(0.5, 0.5) }
				)
				tween:Play()

				return function()
					tween:Cancel()
				end
			end,

			Leave = function(canvas: CanvasGroup, props)
				const tween = TweenService:Create(
					canvas,
					CreateInfo(props),
					{ Position = UDim2.fromScale(-1.5, 0.5) }
				)

				tween.Completed:Once(function()
					canvas.GroupTransparency = 0
					canvas.Visible = false
					canvas.Position = UDim2.fromScale(0.5, 0.5)
				end)

				tween:Play()

				return function()
					tween:Cancel()
				end
			end,
		},
	},
}
