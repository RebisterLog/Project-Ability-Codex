const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)

const CardView = require(script.Parent.CardView)

const Children = Fusion.Children
const OnEvent = Fusion.OnEvent
const peek = Fusion.peek
type UsedAs<T> = Fusion.UsedAs<T>

export type Card = {
	Name: string,
	SpecName: string,
	Icon: string,
	Description: string,
	RarityColor: Color3,
	Equipped: boolean,
}

const TabView = function(
	scope: Fusion.Scope,
	props: {
		Cards: UsedAs<{ [string]: Card }>,
		SelectedKey: UsedAs<string>,
		EquipLabel: string,
		ShowUnequip: boolean,
		OnSelect: (key: string) -> (),
		OnEquip: (key: string) -> (),
		OnUnequip: (key: string) -> (),
		OnDelete: (key: string) -> (),
	}
)
	const activeKey = scope:Computed(function(use)
		const key = use(props.SelectedKey)
		const cards = use(props.Cards)
		if cards[key] then return key end

		for firstKey in cards do
			return firstKey
		end

		return ""
	end)

	const selectedCard = scope:Computed(function(use)
		const cards = use(props.Cards)
		return cards[use(activeKey)]
	end)

	const description = scope:Computed(function(use)
		const card = use(selectedCard)
		return if card then card.Description else ""
	end)

	const portraitIcon = scope:Computed(function(use)
		const card = use(selectedCard)
		return if card then card.Icon else ""
	end)

	const cards = scope:ForPairs(props.Cards, function(use, cardScope, key, card)
		return key,
			CardView(cardScope, {
				Name = card.Name,
				Icon = if card.Icon ~= "" then card.Icon else "",
				RarityColor = card.RarityColor,
				Equipped = card.Equipped,
				Selected = cardScope:Computed(function(use)
					return use(activeKey) == key
				end),
				OnClick = function()
					props.OnSelect(key)
				end,
			})
	end)

	const portraitPlaceholderVisible = scope:Computed(function(use)
		return use(portraitIcon) == ""
	end)

	const selectedEquipped = scope:Computed(function(use)
		const card = use(selectedCard)
		return card ~= nil and card.Equipped
	end)

	const equipColor = scope:Computed(function(use)
		return if use(selectedEquipped)
			then Color3.fromRGB(253, 175, 32)
			else Color3.fromRGB(0, 230, 118)
	end)

	const equipText = scope:Computed(function(use)
		return if use(selectedEquipped) then "Equipped" else props.EquipLabel
	end)

	const slotSize = if props.ShowUnequip then 0.3 else 0.4065
	const deleteOrder = if props.ShowUnequip then 3 else 2

	const actions: { any } = {
		scope:New("Frame")({
			Name = "ActionSlot_Equip",
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, slotSize),

			[Children] = {
				scope:Button(scope:New("TextButton")({
					Name = "Equip",
					AnchorPoint = Vector2.new(0.5, 0.5),
					AutoButtonColor = false,
					BackgroundColor3 = Color3.fromRGB(0, 230, 118),
					BackgroundTransparency = 0.92,
					BorderSizePixel = 0,
					FontFace = Font.new("rbxasset://fonts/families/RobotoCondensed.json"),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1, 1),
					Text = equipText,
					TextColor3 = equipColor,
					TextScaled = true,
					Active = scope:Computed(function(use)
						return not use(selectedEquipped)
					end),

					[OnEvent("MouseButton1Click")] = function()
						const key = peek(activeKey)
						if key ~= "" then props.OnEquip(key) end
					end,

					[Children] = {
						scope:New("UIStroke")({
							Name = "Outline",
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							Color = equipColor,
							Thickness = 2,
						}),
						scope:New("UICorner")({
							Name = "Corner",
							CornerRadius = UDim.new(0.008, 3),
						}),
						scope:New("UITextSizeConstraint")({
							Name = "TextSizeCap",
							MaxTextSize = 60,
						}),
					},
				})),
			},
		}),
	}

	if props.ShowUnequip then
		table.insert(
			actions,
			scope:New("Frame")({
				Name = "ActionSlot_Unequip",
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, slotSize),

				[Children] = {
					scope:Button(scope:New("TextButton")({
						Name = "Unequip",
						AnchorPoint = Vector2.new(0.5, 0.5),
						AutoButtonColor = false,
						BackgroundColor3 = Color3.fromRGB(255, 45, 111),
						BackgroundTransparency = 0.92,
						BorderSizePixel = 0,
						FontFace = Font.new("rbxasset://fonts/families/RobotoCondensed.json"),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(1, 1),
						Text = "Unequip",
						TextColor3 = Color3.fromRGB(255, 45, 111),
						TextScaled = true,

						[OnEvent("MouseButton1Click")] = function()
							const key = peek(activeKey)
							if key ~= "" then props.OnUnequip(key) end
						end,

						[Children] = {
							scope:New("UIStroke")({
								Name = "Outline",
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Color = Color3.fromRGB(255, 45, 111),
								Thickness = 2,
							}),
							scope:New("UICorner")({
								Name = "Corner",
								CornerRadius = UDim.new(0.008, 3),
							}),
							scope:New("UITextSizeConstraint")({
								Name = "TextSizeCap",
								MaxTextSize = 60,
							}),
						},
					})),
				},
			})
		)
	end

	table.insert(
		actions,
		scope:New("Frame")({
			Name = "ActionSlot_Delete",
			BackgroundTransparency = 1,
			LayoutOrder = deleteOrder,
			Size = UDim2.fromScale(1, slotSize),

			[Children] = {
				scope:Button(scope:New("TextButton")({
					Name = "Delete",
					AnchorPoint = Vector2.new(0.5, 0.5),
					AutoButtonColor = false,
					BackgroundColor3 = Color3.fromRGB(255, 45, 111),
					BackgroundTransparency = 0.92,
					BorderSizePixel = 0,
					FontFace = Font.new("rbxasset://fonts/families/RobotoCondensed.json"),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1, 1),
					Text = "Delete",
					TextColor3 = Color3.fromRGB(255, 45, 111),
					TextScaled = true,

					[OnEvent("MouseButton1Click")] = function()
						const key = peek(activeKey)
						if key ~= "" then props.OnDelete(key) end
					end,

					[Children] = {
						scope:New("UIStroke")({
							Name = "Outline",
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							Color = Color3.fromRGB(255, 45, 111),
							Thickness = 2,
						}),
						scope:New("UICorner")({
							Name = "Corner",
							CornerRadius = UDim.new(0.008, 3),
						}),
						scope:New("UITextSizeConstraint")({
							Name = "TextSizeCap",
							MaxTextSize = 60,
						}),
					},
				})),
			},
		})
	)

	table.insert(
		actions,
		scope:New("UIListLayout")({
			Name = "List",
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
	)

	return scope:New("Frame")({
		Name = "Tab",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),

		[Children] = {
			scope:New("ScrollingFrame")({
				Name = "Grid",
				BackgroundTransparency = 1,
				CanvasSize = UDim2.fromScale(0.375, 1.32),
				Position = UDim2.fromScale(0.0255, 0.196),
				ScrollBarImageColor3 = Color3.fromRGB(232, 232, 232),
				ScrollBarThickness = 6,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				Size = UDim2.fromScale(0.375, 0.66),

				[Children] = {
					scope:New("UIGridLayout")({
						Name = "CardGrid",
						CellPadding = UDim2.fromScale(0.03, 0.02),
						CellSize = UDim2.fromScale(0.27, 0.24),
					}),
					scope:New("UIPadding")({
						Name = "GridInset",
						PaddingLeft = UDim.new(0.005, 1),
						PaddingTop = UDim.new(0.005, 1),
					}),
					cards,
				},
			}),

			scope:New("Frame")({
				Name = "Portrait",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.588, 0.196),
				Size = UDim2.fromScale(0.157, 0.546),

				[Children] = {
					scope:New("UIStroke")({
						Name = "Outline",
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Color3.fromRGB(232, 232, 232),
						Thickness = 2,
					}),
					scope:New("ImageLabel")({
						Name = "PortraitImage",
						BackgroundColor3 = Color3.fromRGB(42, 36, 29),
						BackgroundTransparency = 0.1,
						Image = portraitIcon,
						ScaleType = Enum.ScaleType.Fit,
						Size = UDim2.fromScale(1, 1),

						[Children] = {
							scope:New("TextLabel")({
								Name = "Placeholder",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								FontFace = Font.new(
									"rbxasset://fonts/families/RobotoCondensed.json"
								),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(0.7, 0.08),
								Text = "PORTRAIT",
								TextColor3 = Color3.fromRGB(150, 160, 170),
								TextScaled = true,
								Visible = portraitPlaceholderVisible,

								[Children] = {
									scope:New("UITextSizeConstraint")({
										Name = "TextSizeCap",
										MaxTextSize = 38,
									}),
								},
							}),
						},
					}),
				},
			}),

			scope:New("Frame")({
				Name = "Actions",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.607, 0.773),
				Size = UDim2.fromScale(0.131, 0.182),
				[Children] = actions,
			}),

			scope:New("ScrollingFrame")({
				Name = "DescriptionScroll",
				BackgroundTransparency = 1,
				CanvasSize = UDim2.fromScale(0.22, 1.1),
				Position = UDim2.fromScale(0.76, 0.2),
				ScrollBarImageColor3 = Color3.fromRGB(232, 232, 232),
				ScrollBarThickness = 6,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				Size = UDim2.fromScale(0.22, 0.55),

				[Children] = {
					scope:New("TextLabel")({
						Name = "Description",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/RobotoCondensed.json"),
						RichText = true,
						Size = UDim2.fromScale(1, 0.9),
						Text = description,
						TextColor3 = Color3.fromRGB(150, 160, 170),
						TextScaled = true,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,

						[Children] = {
							scope:New("UITextSizeConstraint")({
								Name = "TextSizeCap",
								MaxTextSize = 26,
							}),
						},
					}),
				},
			}),
		},
	})
end

return TabView
