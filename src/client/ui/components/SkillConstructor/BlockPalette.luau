const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)
const Registry = require(ReplicatedStorage.shared.packages.SkillConstructor.registry)
const SearchTextMatch = require(script.Parent.Parent.Parent.utils.SearchTextMatch)
const Theme = require(script.Parent.Theme)

const Children = Fusion.Children
const OnEvent = Fusion.OnEvent

--- `SearchTextMatch` зовёт `string.match(строки, запрос)`, то есть запрос трактуется
--- как паттерн: скобка или плюс в поиске уронили бы палитру. Символы экранируются, а
--- уже экранированный `%` схлопывается обратно, иначе `gsub` снял бы экранирование
--- дважды и `%%` превратился бы в пустую строку.
const escapePattern = function(text: string): string
	const escaped = text:gsub("[%^%$%.%+%-%*%(%)%%]", "%%%1")
	return (escaped:gsub("%%%%", "%%"))
end

const matches = function(query: string, text: string): boolean
	if query == "" then return true end
	return SearchTextMatch(text, escapePattern(query))
end

const paletteEntry = function(
	scope: Fusion.Scope,
	store: any,
	blockId: string,
	order: number
): Instance
	const definition = Registry.get(blockId)
	const color =
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
	const statement = props.Store

	const categories = scope:Computed(function(use)
		const query = use(statement.SearchQuery)
		const result = {}

		for order, category in Registry.CATEGORY_ORDER do
			const entries = {}

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
				const entries = category.Entries
				const hasEntries = #entries > 0

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
