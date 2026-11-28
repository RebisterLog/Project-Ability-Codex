const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)

const Background = require(script.Parent.Background)

const Children = Fusion.Children
const OnEvent = Fusion.OnEvent
type UsedAs<T> = Fusion.UsedAs<T>

const Content = function(
	scope: Fusion.Scope,
	props: {
		ActiveTab: UsedAs<string>,
		Tabs: { [string]: { Label: string, Order: number } },
		Pages: { [string]: Instance },
		OnTabClick: (id: string) -> (),
	}
)
	const tabs = scope:ForPairs(props.Tabs, function(use, tabScope, key, tab)
		const color = tabScope:Computed(function(use)
			return if use(props.ActiveTab) == key
				then Color3.fromRGB(0, 230, 118)
				else Color3.fromRGB(232, 232, 232)
		end)

		return key,
			tabScope:New("Frame")({
				Name = `TabSlot_{key}`,
				BackgroundTransparency = 1,
				LayoutOrder = tab.Order,
				Size = UDim2.fromScale(0.185, 1),

				[Children] = {
					tabScope:Button(tabScope:New("TextButton")({
						Name = key,
						AnchorPoint = Vector2.new(0.5, 0.5),
						AutoButtonColor = false,
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/RobotoCondensed.json"),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(1, 1),
						Text = tab.Label,
						TextColor3 = color,
						TextScaled = true,

						[OnEvent("MouseButton1Click")] = function()
							props.OnTabClick(key)
						end,

						[Children] = {
							tabScope:New("UIStroke")({
								Name = "Outline",
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Color = color,
								Thickness = 2,
							}),
							tabScope:New("UICorner")({
								Name = "Corner",
								CornerRadius = UDim.new(0.006, 2),
							}),
							tabScope:New("UITextSizeConstraint")({
								Name = "TextSizeCap",
								MaxTextSize = 60,
							}),
						},
					})),
				},
			})
	end)

	const pages = scope:ForPairs(props.Pages, function(use, pageScope, key, page)
		return key,
			pageScope:New("Frame")({
				Name = key,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Visible = pageScope:Computed(function(use)
					return use(props.ActiveTab) == key
				end),

				[Children] = { page },
			})
	end)

	return scope:New("Frame")({
		Name = "Content",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,

		[Children] = {
			Background(scope),

			scope:New("TextLabel")({
				Name = "Version",
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/RobotoCondensed.json"),
				Position = UDim2.fromScale(0.0026, 0.978),
				Size = UDim2.fromScale(0.12, 0.022),
				Text = "Alpha v0.0.1",
				TextColor3 = Color3.fromRGB(232, 232, 232),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,

				[Children] = {
					scope:New("UITextSizeConstraint")({
						Name = "TextSizeCap",
						MaxTextSize = 20,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "Tabs",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.161, 0.009),
				Size = UDim2.fromScale(0.678, 0.074),

				[Children] = {
					tabs,
					scope:New("UIListLayout")({
						Name = "List",
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0.017, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Center,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "Pages",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				[Children] = pages,
			}),
		},
	})
end

return Content
