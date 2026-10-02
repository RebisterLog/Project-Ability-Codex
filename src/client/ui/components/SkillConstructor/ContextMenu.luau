local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.shared.packages.Fusion)
local Theme = require(script.Parent.Theme)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

--- Контекстное меню блока: дублировать, свернуть, перенести в слот, удалить.
---
--- Меню одно на страницу и живёт поверх таймлайна: на каждый блок свой экземпляр
--- означал бы десятки скрытых панелей и конфликт за `ZIndex`. Позиция и видимость
--- хранятся в состоянии, поэтому закрытие — это одна запись, а не обход дерева.
return function(scope: Fusion.Scope, props: any)
	local statement = props.Store

	local target = scope:Computed(function(use)
		local id = use(statement.contextBlockId)
		if id == nil then return nil end

		local blueprint = use(statement.Blueprint)
		local block = statement.findBlock(blueprint, id)
		if block == nil then return nil end

		return {
			Id = id,
			Type = block.Type,
			Slots = statement.registry.getSlots(block.Type),
			Revision = use(statement.revision),
		}
	end)

	local function item(order: number, label: string, run: () -> ()): Instance
		return scope:New("TextButton")({
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, Theme.MinClick),
			BackgroundColor3 = Theme.Colors.SurfaceAlt,
			BorderSizePixel = 0,
			AutoButtonColor = true,
			Selectable = true,
			Text = label,
			TextColor3 = Theme.Colors.Text,
			TextSize = 12,
			Font = Theme.Font,

			[Children] = {
				Corner = scope:New("UICorner")({
					CornerRadius = UDim.new(0, Theme.Radius.Button),
				}),

				Padding = scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, Theme.Spacing.Small),
				}),
			},

			[OnEvent("Activated")] = function()
				run()
				statement.setContextBlockId(nil)
			end,
		})
	end

	local slots = scope:Computed(function(use)
		local current = use(target)
		if current == nil then return {} end

		local result = {}
		for index, slot in current.Slots do
			table.insert(result, { Slot = slot, Order = index })
		end
		return result
	end)

	return scope:New("Frame")({
		Name = "ContextMenu",
		Size = UDim2.fromOffset(180, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = scope:Computed(function(use)
			return use(statement.contextBlockId) ~= nil
		end),
		Position = statement.contextPosition,
		BackgroundColor3 = Theme.Colors.Surface,
		BorderSizePixel = 0,
		ZIndex = 20,

		[Children] = {
			Stroke = scope:New("UIStroke")({
				Color = Theme.Colors.Outline,
				Thickness = 1,
				Transparency = 0.3,
			}),

			Layout = scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.Spacing.Tiny),
			}),

			Padding = scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, Theme.Spacing.Tiny),
				PaddingRight = UDim.new(0, Theme.Spacing.Tiny),
				PaddingTop = UDim.new(0, Theme.Spacing.Tiny),
			}),

			Title = scope:New("TextLabel")({
				LayoutOrder = 0,
				Size = UDim2.new(1, -8, 0, 20),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use)
					local current = use(target)
					if current == nil then return "" end
					return current.Type
				end),
				TextColor3 = Theme.Colors.Accent,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Font,
			}),

			--- Слоты контейнера выводятся списком: у `ProcessAttack` их семь, и
			--- перенос в конкретный слот — обычное действие при сборке скилла.
			Slots = scope:ForValues(slots, function(use, slotScope, entry)
				return slotScope:New("TextButton")({
					LayoutOrder = entry.Order,
					Size = UDim2.new(1, -8, 0, Theme.MinClick),
					BackgroundColor3 = Theme.Colors.Surface,
					BorderSizePixel = 0,
					AutoButtonColor = true,
					Selectable = true,
					Text = `→ {entry.Slot}`,
					TextColor3 = Theme.Colors.TextMuted,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					Font = Theme.Font,

					[OnEvent("Activated")] = function()
						local current = use(target)
						if current == nil then return end
						statement.moveBlockToSlot(current.Id, entry.Slot)
						statement.setContextBlockId(nil)
					end,
				})
			end),

			Duplicate = item(50, "Дублировать", function()
				local current = Fusion.peek(target)
				if current == nil then return end
				statement.duplicateBlock(current.Id)
			end),

			Collapse = item(51, "Свернуть / развернуть", function()
				local current = Fusion.peek(target)
				if current == nil then return end
				statement.toggleCollapsed(current.Id)
			end),

			Remove = item(52, "Удалить", function()
				local current = Fusion.peek(target)
				if current == nil then return end
				statement.removeBlock(current.Id)
			end),
		},
	})
end
