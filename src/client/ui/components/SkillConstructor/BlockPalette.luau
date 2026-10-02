local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.shared.packages.Fusion)
local Registry = require(ReplicatedStorage.shared.packages.SkillConstructor.registry)
local SearchTextMatch = require(script.Parent.Parent.Parent.utils.SearchTextMatch)
local Theme = require(script.Parent.Theme)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

--- `SearchTextMatch` зовёт `string.match(строки, запрос)`, то есть запрос трактуется
--- как паттерн: скобка или плюс в поиске уронили бы палитру. Символы экранируются, а
--- уже экранированный `%` схлопывается обратно, иначе `gsub` снял бы экранирование
--- дважды и `%%` превратился бы в пустую строку.
local function escapePattern(text: string): string
	local escaped = text:gsub("[%^%$%.%+%-%*%(%)%%]", "%%%1")
	return (escaped:gsub("%%%%", "%%"))
end

local function matches(query: string, text: string): boolean
	if query == "" then return true end
	return SearchTextMatch(text, escapePattern(query))
end

local function paletteEntry(
	scope: Fusion.Scope,
	store: any,
	blockId: string,
	order: number
): Instance
	local definition = Registry.get(blockId)
	local color =
		Theme.hexToColor3(definition.Color or Registry.CATEGORY_COLORS[definition.Category])

	return scope:New("TextButton")({
		Name = definition.DisplayName,
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, Theme.MinClick),
		BackgroundColor3 = Theme.Colors.SurfaceAlt,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		Selectable = true,
		Text = definition.DisplayName,
		TextColor3 = color,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.Font,

		[Children] = {
			Corner = scope:New("UICorner")({
				CornerRadius = UDim.new(0, Theme.Radius.Button),
			}),
		},

		[OnEvent("Activated")] = function()
			store.addBlock(blockId)
		end,
	})
end

--- Левая колонка: категории в порядке `registry.CATEGORY_ORDER`, внутри категории
--- сортировка по названию, чтобы список не прыгал при добавлении блоков (§10).
---
--- Категории и блоки — два вложенных списка, поэтому на каждый уровень своя
--- `UIListLayout`. При пустом поиске видны все категории, при непустом — только те,
--- где что-то нашлось; `ForValues` сам пересобирает список, поэтому фильтр не
--- требует ручного обновления GUI-инстансов.
return function(scope: Fusion.Scope, props: any)
	local statement = props.Store

	local categories = scope:Computed(function(use)
		local query = use(statement.SearchQuery)
		local result = {}

		for order, category in Registry.CATEGORY_ORDER do
			local entries = {}

			for index, definition in Registry.getByCategory(category) do
				if matches(query, definition.DisplayName) or matches(query, definition.Id) then
					table.insert(entries, { Id = definition.Id, Order = index })
				end
			end

			table.insert(result, { Category = category, Entries = entries, Order = order })
		end

		return result
	end)

	return scope:New("ScrollingFrame")({
		Name = "BlockPalette",
		Size = UDim2.fromScale(0.18, 1),
		BackgroundColor3 = Theme.Colors.Surface,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,

		[Children] = {
			Padding = scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, Theme.Spacing.Small),
				PaddingRight = UDim.new(0, Theme.Spacing.Small),
				PaddingTop = UDim.new(0, Theme.Spacing.Small),
			}),
		},

		[Children] = {
			Layout = scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.Spacing.Small),
			}),

			Categories = scope:ForValues(categories, function(use, childScope, category)
				local entries = category.Entries
				local hasEntries = #entries > 0

				return childScope:New("Frame")({
					Name = category.Category,
					Visible = hasEntries,
					LayoutOrder = category.Order,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,

					[Children] = {
						Title = childScope:New("TextLabel")({
							Size = UDim2.new(1, 0, 0, 20),
							BackgroundTransparency = 1,
							Text = `{category.Category}  ×{#entries}`,
							TextColor3 = Theme.Colors.TextMuted,
							TextSize = 11,
							TextXAlignment = Enum.TextXAlignment.Left,
							Font = Theme.Font,
						}),

						Layout = childScope:New("UIListLayout")({
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, Theme.Spacing.Tiny),
						}),

						Entries = childScope:ForValues(entries, function(use, entryScope, entry)
							return paletteEntry(entryScope, statement, entry.Id, entry.Order)
						end),
					},
				})
			end),
		},
	})
end
