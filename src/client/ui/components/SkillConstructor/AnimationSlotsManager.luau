const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)
const Theme = require(script.Parent.Theme)

const Children = Fusion.Children
const OnEvent = Fusion.OnEvent

--- Менеджер слотов анимаций.
---
--- Слот — это именованная ссылка на ключ из `Spec.Data.Assets.Animations`; сам
--- blueprint хранит только `Id` слота и строку `AnimationId`, поэтому перенос скилла
--- между спеками не ломает код (§4, `types.luau:124-145`). `FadeInTime` здесь нет:
--- у `onStart` входа такого параметра не существует, он применим только к
--- `StopAnimation` (`effects/Animation.luau:45-53`).
return function(scope: Fusion.Scope, props: any)
	const statement = props.Store

	const field = function(
		order: number,
		caption: string,
		value: any,
		width: number,
		commit: (string) -> ()
	): Instance
		const box = scope:New("TextBox")({
			LayoutOrder = order,
			Size = UDim2.new(width, -4, 0, 22),
			BackgroundColor3 = Theme.Colors.SurfaceAlt,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Text = tostring(value or ""),
			PlaceholderText = caption,
			PlaceholderColor3 = Theme.Colors.TextMuted,
			TextColor3 = Theme.Colors.Text,
			TextSize = 11,
			Font = Theme.Font,

			[Children] = {
				Corner = scope:New("UICorner")({
					CornerRadius = UDim.new(0, Theme.Radius.Button),
				}),

				Padding = scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, Theme.Spacing.Tiny),
					PaddingRight = UDim.new(0, Theme.Spacing.Tiny),
				}),
			},
		})

		table.insert(
			scope,
			box.FocusLost:Connect(function()
				commit(box.Text)
			end)
		)

		return box
	end

	--- Список слотов пересобирается на каждую мутацию blueprint: имена и `Id`
	--- меняются только из UI, поэтому пересоздание дешевле ручной синхронизации.
	const slots = scope:Computed(function(use)
		const current = use(statement.revision)
		const result = {}

		for index, slot in use(statement.Blueprint).AnimationSlots do
			table.insert(result, { Slot = slot, Order = index, Revision = current })
		end

		return result
	end)

	return scope:New("ScrollingFrame")({
		Name = "AnimationSlotsManager",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,

		[Children] = {
			Padding = scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, Theme.Spacing.Small),
				PaddingRight = UDim.new(0, Theme.Spacing.Small),
				PaddingTop = UDim.new(0, Theme.Spacing.Small),
			}),

			Layout = scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.Spacing.Small),
			}),

			Header = scope:New("TextLabel")({
				LayoutOrder = 0,
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				Text = "Слоты анимаций",
				TextColor3 = Theme.Colors.TextMuted,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Font,
			}),

			Add = scope:New("TextButton")({
				Name = "AddSlot",
				LayoutOrder = 1,
				Size = UDim2.new(1, -4, 0, Theme.MinClick),
				BackgroundColor3 = Theme.Colors.SurfaceAlt,
				BorderSizePixel = 0,
				AutoButtonColor = true,
				Selectable = true,
				Text = "+ Добавить слот",
				TextColor3 = Theme.Colors.Text,
				TextSize = 12,
				Font = Theme.Font,

				[Children] = {
					Corner = scope:New("UICorner")({
						CornerRadius = UDim.new(0, Theme.Radius.Button),
					}),
				},

				[OnEvent("Activated")] = function()
					statement.addSlot()
				end,
			}),

			Slots = scope:ForValues(slots, function(use, rowScope, entry)
				const slot = entry.Slot

				return rowScope:New("Frame")({
					Name = slot.Id,
					LayoutOrder = entry.Order + 1,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,

					[Children] = {
						Layout = rowScope:New("UIListLayout")({
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, Theme.Spacing.Tiny),
						}),

						Title = rowScope:New("TextLabel")({
							LayoutOrder = 0,
							Size = UDim2.new(1, 0, 0, 18),
							BackgroundTransparency = 1,
							Text = `Слот {entry.Order}: {slot.Id}`,
							TextColor3 = Theme.Colors.Accent,
							TextSize = 11,
							TextXAlignment = Enum.TextXAlignment.Left,
							Font = Theme.Font,
						}),

						Name = field(1, "Имя", slot.Name, 0.5, function(value)
							statement.setSlot(slot.Id, "Name", value)
						end),

						AnimationId = field(
							2,
							"AnimationId",
							slot.AnimationId,
							0.5,
							function(value)
								statement.setSlot(slot.Id, "AnimationId", value)
							end
						),

						Speed = field(3, "Speed", slot.Speed, 0.5, function(value)
							const parsed = tonumber(value)
							statement.setSlot(slot.Id, "Speed", if parsed ~= nil then parsed else 1)
						end),

						FadeTime = field(4, "FadeTime", slot.FadeTime, 0.5, function(value)
							const parsed = tonumber(value)
							statement.setSlot(
								slot.Id,
								"FadeTime",
								if parsed ~= nil then parsed else 0
							)
						end),

						Remove = rowScope:New("TextButton")({
							LayoutOrder = 5,
							Size = UDim2.new(1, -4, 0, 24),
							BackgroundColor3 = Theme.Colors.Surface,
							BorderSizePixel = 0,
							AutoButtonColor = true,
							Selectable = true,
							Text = "Удалить слот",
							TextColor3 = Theme.Colors.Error,
							TextSize = 11,
							Font = Theme.Font,

							[Children] = {
								Corner = rowScope:New("UICorner")({
									CornerRadius = UDim.new(0, Theme.Radius.Button),
								}),
							},

							[OnEvent("Activated")] = function()
								statement.removeSlot(slot.Id)
							end,
						}),
					},
				})
			end),
		},
	})
end
