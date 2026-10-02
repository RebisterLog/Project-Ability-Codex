local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BotCharacters = require(ReplicatedStorage.shared["bot-characters"])
local Fusion = require(ReplicatedStorage.shared.packages.Fusion)
local Theme = require(script.Parent.Theme)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

--- Теги ботов, которые можно выдать скиллу. Список приходит из общего модуля, а не
--- дублируется здесь: новый тег в `bot-characters` сразу появляется в UI.
local TAGS = {}
for tag in BotCharacters.SkillCharacters do
	table.insert(TAGS, tag)
end
table.sort(TAGS)

--- Панель настроек скилла: `DisplayName`, `Id`, `Cooldown`, выбор источника ассетов
--- и мультиселект тегов (§10).
---
--- `Id` валидируется тем же правилом, что и в CLI: `[A-Za-z0-9_]+` плюс запрет
--- символов, недопустимых в имени файла Windows. Невалидный `Id` подсвечивается и
--- оставляется в поле, но экспорт его не пропустит — так ошибка видна сразу, а не
--- на `lune run` через полчаса.
return function(scope: Fusion.Scope, props: any)
	local statement = props.Store

	--- Поле ввода привязано к blueprint, но не затирает набор пользователя: пока
	--- фокус в поле, текст принадлежит ему, а модель обновляется по `FocusLost`.
	--- Иначе `Import JSON` не смог бы показать загруженные значения.
	local function textField(
		order: number,
		caption: string,
		field: string,
		dirty: { [string]: boolean }
	): Instance
		local box = scope:New("TextBox")({
			LayoutOrder = order,
			Size = UDim2.new(1, -4, 0, 24),
			BackgroundColor3 = Theme.Colors.SurfaceAlt,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Text = tostring(statement.peekBlueprint()[field] or ""),
			PlaceholderText = caption,
			PlaceholderColor3 = Theme.Colors.TextMuted,
			TextColor3 = Theme.Colors.Text,
			TextSize = 12,
			Font = Theme.Font,

			[Children] = {
				Corner = scope:New("UICorner")({
					CornerRadius = UDim.new(0, Theme.Radius.Button),
				}),

				Padding = scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, Theme.Spacing.Small),
					PaddingRight = UDim.new(0, Theme.Spacing.Small),
				}),
			},
		})

		table.insert(
			scope,
			box:GetPropertyChangedSignal("Text"):Connect(function()
				dirty[field] = true
			end)
		)

		table.insert(
			scope,
			box.Focused:Connect(function()
				dirty[field] = true
			end)
		)

		table.insert(
			scope,
			box.FocusLost:Connect(function()
				dirty[field] = nil
				local value = box.Text
				if field == "Cooldown" then
					local parsed = tonumber(value)
					statement.setField("Cooldown", if parsed ~= nil then math.max(0, parsed) else 0)
				else
					statement.setField(field, value)
				end
			end)
		)

		return box
	end

	--- Строка «подпись + поле». Подпись отдельной строкой, а не плейсхолдером:
	--- плейсхолдер исчезает при вводе, и поле теряло бы имя.
	local function labelledRow(
		order: number,
		label: string,
		control: Instance,
		hint: string?
	): Instance
		local children = {
			Label = scope:New("TextLabel")({
				LayoutOrder = 0,
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				Text = label,
				TextColor3 = Theme.Colors.TextMuted,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Font,
			}),
			Control = control,
		}

		if hint ~= nil then
			children.Hint = scope:New("TextLabel")({
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundTransparency = 1,
				Text = hint,
				TextColor3 = Theme.Colors.TextMuted,
				TextSize = 10,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Font,
			})
		end

		return scope:New("Frame")({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,

			[Children] = {
				Layout = scope:New("UIListLayout")({
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, Theme.Spacing.Tiny),
				}),

				Body = children,
			},
		})
	end

	local blueprint = statement.Blueprint

	local dirty: { [string]: boolean } = {}

	local idField = textField(1, "Id", "Id", dirty)
	local displayNameField = textField(2, "Display name", "DisplayName", dirty)
	local cooldownField = textField(3, "Cooldown", "Cooldown", dirty)

	--- Источник ассетов — переключатель из двух значений, а не выпадающий список:
	--- вариантов ровно два (`Spec` / `Stand`, §4), а список занял бы строку впустую.
	local function assetButton(value: string, order: number): Instance
		return scope:New("TextButton")({
			LayoutOrder = order,
			Size = UDim2.new(0.5, -2, 0, Theme.MinClick),
			BackgroundColor3 = scope:Computed(function(use)
				if use(blueprint).AssetSource == value then return Theme.Colors.Accent end
				return Theme.Colors.SurfaceAlt
			end),
			BorderSizePixel = 0,
			AutoButtonColor = true,
			Selectable = true,
			Text = value,
			TextColor3 = scope:Computed(function(use)
				if use(blueprint).AssetSource == value then return Theme.Colors.Background end
				return Theme.Colors.TextMuted
			end),
			TextSize = 12,
			Font = Theme.Font,

			[Children] = {
				Corner = scope:New("UICorner")({
					CornerRadius = UDim.new(0, Theme.Radius.Button),
				}),
			},

			[OnEvent("Activated")] = function()
				statement.setAssetSource(value)
			end,
		})
	end

	local tagButtons = {}
	for index, tag in TAGS do
		tagButtons[index] = scope:New("TextButton")({
			Name = tag,
			LayoutOrder = index,
			Size = UDim2.new(0.5, -2, 0, Theme.MinClick - 4),
			BackgroundColor3 = scope:Computed(function(use)
				local list = use(blueprint).SkillCharacters or {}
				if table.find(list, tag) ~= nil then return Theme.Colors.Accent end
				return Theme.Colors.Surface
			end),
			BorderSizePixel = 0,
			AutoButtonColor = true,
			Selectable = true,
			Text = tag,
			TextColor3 = scope:Computed(function(use)
				local list = use(blueprint).SkillCharacters or {}
				if table.find(list, tag) ~= nil then return Theme.Colors.Background end
				return Theme.Colors.TextMuted
			end),
			TextSize = 11,
			Font = Theme.Font,

			[Children] = {
				Corner = scope:New("UICorner")({
					CornerRadius = UDim.new(0, Theme.Radius.Button),
				}),
			},

			[OnEvent("Activated")] = function()
				statement.toggleSkillCharacter(tag)
			end,
		})
	end

	return scope:New("ScrollingFrame")({
		Name = "SkillSettings",
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
				Padding = UDim.new(0, Theme.Spacing.Medium),
			}),

			Id = labelledRow(1, "Id *", idField, "Имя модуля скилла: [A-Za-z0-9_]"),
			DisplayName = labelledRow(2, "Display name", displayNameField),
			Cooldown = labelledRow(
				3,
				"Cooldown",
				cooldownField,
				"Пауза между применениями, секунды"
			),
			AssetSource = labelledRow(
				4,
				"Источник ассетов",
				scope:New("Frame")({
					Size = UDim2.new(1, 0, 0, Theme.MinClick),
					BackgroundTransparency = 1,

					[Children] = {
						Layout = scope:New("UIListLayout")({
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, Theme.Spacing.Tiny),
						}),

						Spec = assetButton("Spec", 1),
						Stand = assetButton("Stand", 2),
					},
				})
			),

			Tags = labelledRow(
				5,
				"Теги ботам",
				scope:New("Frame")({
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,

					[Children] = {
						Layout = scope:New("UIGridLayout")({
							SortOrder = Enum.SortOrder.LayoutOrder,
							CellSize = UDim2.new(0.5, -2, 0, Theme.MinClick - 4),
							CellPadding = UDim2.new(0, Theme.Spacing.Tiny),
						}),

						Buttons = tagButtons,
					},
				}),
				"Hit нужен при наличии Hitbox — иначе боты упадут"
			),
		},
	})
end
