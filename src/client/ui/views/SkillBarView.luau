const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)

const Children = Fusion.Children
const OnEvent = Fusion.OnEvent
type UsedAs<T> = Fusion.UsedAs<T>

export type SkillCell = {
	Id: string,
	Slot: string,
	SpecName: string,
	Order: number,
	Palette: {
		BackgroundColor: Color3?,
		NameColor: Color3?,
		CooldownColor: Color3?,
		TimerColor: Color3?,
		BindColor: Color3?,
		BindTextColor: Color3?,
	}?,
	DisplayName: UsedAs<string>,
	BindLabel: UsedAs<string>,
	Remaining: UsedAs<number>,
	Ratio: UsedAs<number>,
	Pop: UsedAs<number>,
	Rebinding: UsedAs<boolean>,
}

const SkillBarView = function(
	scope: Fusion.Scope,
	props: {
		Skills: UsedAs<{ [string]: SkillCell }>,
		OnHoldStart: (key: string) -> (),
		OnHoldEnd: (key: string) -> (),
	}
)
	const cells = scope:ForPairs(props.Skills, function(use, cellScope, key, cell)
		const pop = cellScope:Spring(cell.Pop, 18, 0.5)

		const size = cellScope:Computed(function(use)
			const scale = 1 - math.clamp(use(pop), 0, 1) * 0.15
			return UDim2.fromScale(scale, scale)
		end)

		const fillSize = cellScope:Computed(function(use)
			return UDim2.fromScale(1, math.clamp(use(cell.Ratio), 0, 1))
		end)

		const timerText = cellScope:Computed(function(use)
			const remaining = use(cell.Remaining)
			return if remaining > 0 then string.format("%.2f", remaining) else ""
		end)

		const strokeColor = cellScope:Computed(function(use)
			return if use(cell.Ratio) > 0
				then Color3.fromRGB(214, 122, 142)
				else Color3.fromRGB(255, 255, 255)
		end)

		const bindText = cellScope:Computed(function(use)
			return if use(cell.Rebinding) then "..." else use(cell.BindLabel)
		end)

		return key,
			cellScope:New("Frame")({
				Name = key,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = cell.Order,
				Size = UDim2.fromScale(0.0417, 0.0757),

				[Children] = {
					cellScope:New("TextButton")({
						Name = "Button",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = if cell.Palette and cell.Palette.BackgroundColor
							then cell.Palette.BackgroundColor
							else Color3.fromRGB(56, 54, 52),
						BorderSizePixel = 0,
						Font = Enum.Font.GothamBold,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = size,
						Text = "",
						TextColor3 = Color3.fromRGB(255, 255, 255),

						[OnEvent("MouseButton1Down")] = function()
							props.OnHoldStart(key)
						end,
						[OnEvent("MouseButton1Up")] = function()
							props.OnHoldEnd(key)
						end,
						[OnEvent("MouseLeave")] = function()
							props.OnHoldEnd(key)
						end,

						[Children] = {
							cellScope:New("UICorner")({
								CornerRadius = UDim.new(0.1, 0),
							}),
							cellScope:New("UIStroke")({
								Color = strokeColor,
								StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
								Thickness = 0.03,
							}),

							cellScope:New("TextLabel")({
								Name = "SkillName",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Font = Enum.Font.GothamBold,
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(0.86, 0.72),
								Text = cell.DisplayName,
								TextColor3 = if cell.Palette and cell.Palette.NameColor
									then cell.Palette.NameColor
									else Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextWrapped = true,
								ZIndex = 2,

								[Children] = {
									cellScope:New("UITextSizeConstraint")({
										MaxTextSize = 18,
									}),
								},
							}),

							cellScope:New("Frame")({
								Name = "CooldownFill",
								AnchorPoint = Vector2.new(0, 1),
								BackgroundColor3 = if cell.Palette
										and cell.Palette.CooldownColor
									then cell.Palette.CooldownColor
									else Color3.fromRGB(180, 90, 100),
								BackgroundTransparency = 0.18,
								BorderSizePixel = 0,
								Position = UDim2.fromScale(0, 1),
								Size = fillSize,
								ZIndex = 3,

								[Children] = {
									cellScope:New("UICorner")({
										CornerRadius = UDim.new(0.1, 0),
									}),
								},
							}),

							cellScope:New("TextLabel")({
								Name = "CooldownTimer",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Font = Enum.Font.GothamBold,
								Position = UDim2.fromScale(0.5, 0.88),
								Size = UDim2.fromScale(1, 0.3),
								Text = timerText,
								TextColor3 = if cell.Palette and cell.Palette.TimerColor
									then cell.Palette.TimerColor
									else Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								ZIndex = 4,

								[Children] = {
									cellScope:New("UITextSizeConstraint")({
										MaxTextSize = 18,
									}),
								},
							}),

							cellScope:New("TextLabel")({
								Name = "BindTab",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundColor3 = if cell.Palette and cell.Palette.BindColor
									then cell.Palette.BindColor
									else Color3.fromRGB(255, 255, 255),
								BorderSizePixel = 0,
								Font = Enum.Font.GothamBold,
								Position = UDim2.fromScale(0.5, 0),
								Size = UDim2.fromScale(0.275, 0.275),
								Text = bindText,
								TextColor3 = if cell.Palette and cell.Palette.BindTextColor
									then cell.Palette.BindTextColor
									else Color3.fromRGB(56, 54, 52),
								TextScaled = true,
								ZIndex = 5,

								[Children] = {
									cellScope:New("UICorner")({
										CornerRadius = UDim.new(0.27, 0),
									}),
									cellScope:New("UITextSizeConstraint")({
										MaxTextSize = 12,
									}),
								},
							}),
						},
					}),
				},
			})
	end)

	return scope:New("Frame")({
		Name = "SkillBar",
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 0.978),

		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0.0031, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
			}),
			cells,
		},
	})
end

return SkillBarView
