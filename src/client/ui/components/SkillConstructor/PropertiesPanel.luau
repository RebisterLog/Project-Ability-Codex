local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Codec = require(ReplicatedStorage.shared.packages.SkillConstructor.codec)
local Fusion = require(ReplicatedStorage.shared.packages.Fusion)
local Theme = require(script.Parent.Theme)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

--- Значение для показа. Внутри редактора свойства лежат в нативных Roblox-типах,
--- а дефолты реестра — в type-tag форме (§8), поэтому показ всегда приводится к
--- нативному виду через `codec.fromTagged`.
local function displayValue(value: any): any
	return Codec.fromTagged(value)
end

--- Компоненты значения по осям. `CFrame` разбирается в порядке `px, py, pz,
--- rx, ry, rz` — ровно как их кладёт `codec.toTagged`, иначе сборка обратно
--- переставила бы оси.
local AXES = {
	Vector3 = { "X", "Y", "Z" },
	Color3 = { "R", "G", "B" },
	CFrame = { "X", "Y", "Z", "RX", "RY", "RZ" },
}

local function components(value: any, primary: string): { number }
	local source = displayValue(value)
	if source == nil then return { 0, 0, 0 } end

	--- Компоненты читаются по именам, а не по индексу: у Roblox-типов числовой
	--- индекс не работает, `__index` ждёт имя свойства. Углы `CFrame` приходят
	--- отдельным вызовом, потому что у самого `CFrame` нет полей `RX/RY/RZ`.
	if primary == "CFrame" then
		local rx, ry, rz = source:ToOrientation()
		return { source.X, source.Y, source.Z, rx, ry, rz }
	elseif primary == "Color3" then
		return { source.R, source.G, source.B }
	end

	return { source.X, source.Y, source.Z }
end

--- Собирает Roblox-значение обратно. `CFrame` — умножением на
--- `fromEulerAnglesYXZ`, как в `codec.fromTagged`: конструктора с шестью числами
--- в Roblox нет, а порядок углов обязан быть YXZ.
local function buildValue(primary: string, parts: { number }): any
	if primary == "Vector3" then
		return Vector3.new(parts[1] or 0, parts[2] or 0, parts[3] or 0)
	elseif primary == "Color3" then
		return Color3.fromRGB(
			math.round((parts[1] or 0) * 255),
			math.round((parts[2] or 0) * 255),
			math.round((parts[3] or 0) * 255)
		)
	elseif primary == "CFrame" then
		return CFrame.new(parts[1] or 0, parts[2] or 0, parts[3] or 0)
			* CFrame.fromEulerAnglesYXZ(parts[4] or 0, parts[5] or 0, parts[6] or 0)
	end

	return parts[1] or 0
end

local function formatNumber(value: number): string
	--- `-0` Roblox отдаёт из `ToOrientation` для нулевого угла; в поле он выглядел бы
	--- как опечатка и мешал сравнению текста.
	if value == 0 then return "0" end
	if value == math.floor(value) then return tostring(math.floor(value)) end
	local text = string.format("%.3f", value)
	while string.sub(text, -1) == "0" do
		text = string.sub(text, 1, -2)
	end
	if string.sub(text, -1) == "." then text = string.sub(text, 1, -2) end
	return text
end

return function(scope: Fusion.Scope, props: any)
	local statement = props.Store
	local registry = statement.registry

	--- Выбранный блок. Пустота — не ошибка, а обычное состояние панели, поэтому
	--- возвращается `nil` и рисуется подсказка.
	local selected = scope:Computed(function(use)
		local id = use(statement.SelectedId)
		local blueprint = use(statement.Blueprint)
		--- Ревизия обязательна: правка свойства меняет блок на месте, и без неё
		--- Fusion счёл бы форму неизменившейся — поля остались бы со старыми
		--- значениями до перевыбора блока.
		local current = use(statement.revision)
		if id == nil then return nil end

		local block = statement.findBlock(blueprint, id)
		if block == nil then return nil end
		return { Block = block, Id = id, Revision = current }
	end)

	--- Поле ввода. Значение читается при потере фокуса: при вводе на лету половина
	--- набора («0.», «-») превращалась бы в `NaN` прямо в модели.
	---
	--- Обработчик подписывается вручную, а не через `[OnEvent]`: у `FocusLost`
	--- первым аргументом приходит булев флаг, а не сам инстанс, и поле пришлось бы
	--- доставать из аргументов события. Соединение кладётся в scope — так его
	--- снимет `doCleanup` при разборе страницы.
	local function numberField(
		order: number,
		caption: string,
		value: number,
		commit: (number) -> ()
	): Instance
		local box = scope:New("TextBox")({
			LayoutOrder = order,
			Size = UDim2.new(0.5, -2, 0, 22),
			BackgroundColor3 = Theme.Colors.SurfaceAlt,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Text = formatNumber(value),
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
				local parsed = tonumber(box.Text)
				if parsed == nil then
					box.Text = formatNumber(value)
					return
				end

				box.Text = formatNumber(parsed)
				commit(parsed)
			end)
		)

		return box
	end

	--- Одна строка формы: подпись, ineffective-подсказка и виджет по типу.
	--- Возвращает словарь детей — их раскладывает вызывающий по `LayoutOrder`.
	local function propertyRow(
		scope: Fusion.Scope,
		entry: any,
		property: any,
		order: number
	): { [string]: any }
		local raw = entry.Block.Properties[property.Name]
		local isSet = raw ~= nil
		local types = if type(property.Type) == "table" then property.Type else { property.Type }
		local primary = types[1]

		local children = {
			Label = scope:New("TextLabel")({
				LayoutOrder = order * 10,
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				Text = `{property.Name}{if property.Required then " *" else ""}`,
				TextColor3 = if isSet then Theme.Colors.Text else Theme.Colors.TextMuted,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Font,
			}),
		}

		if primary == "boolean" then
			local isOn = if isSet then raw == true else property.Default == true
			children.Control = scope:New("TextButton")({
				LayoutOrder = order * 10 + 1,
				Size = UDim2.fromOffset(28, 22),
				BackgroundColor3 = if isOn then Theme.Colors.Accent else Theme.Colors.SurfaceAlt,
				BorderSizePixel = 0,
				AutoButtonColor = true,
				Selectable = true,
				Text = if isOn then "✓" else "",
				TextColor3 = Theme.Colors.Background,
				TextSize = 12,
				Font = Theme.Font,

				[Children] = {
					Corner = scope:New("UICorner")({
						CornerRadius = UDim.new(0, Theme.Radius.Button),
					}),
				},

				[OnEvent("Activated")] = function()
					statement.setProperty(entry.BlockId, property.Name, not isOn)
				end,
			})
		elseif primary == "enum" then
			--- Варианты enum всегда короткие и заданы реестром, поэтому выводятся
			--- кнопками в ряд: выпадающий список внутри скролл-фрейма панели
			--- перехватывал бы прокрутку. Повторный клик по активному варианту
			--- снимает значение — так поле снова становится «не задано».
			local current = if isSet then tostring(raw) else nil
			local options = property.Options or {}

			for index, option in options do
				local isActive = option == current
				children[`Option{index}`] = scope:New("TextButton")({
					LayoutOrder = order * 10 + index,
					Size = UDim2.new(0.5, -2, 0, 22),
					BackgroundColor3 = if isActive
						then Theme.Colors.Accent
						else Theme.Colors.SurfaceAlt,
					BorderSizePixel = 0,
					AutoButtonColor = true,
					Selectable = true,
					Text = option,
					TextColor3 = if isActive
						then Theme.Colors.Background
						else Theme.Colors.TextMuted,
					TextSize = 10,
					Font = Theme.Font,

					[Children] = {
						Corner = scope:New("UICorner")({
							CornerRadius = UDim.new(0, Theme.Radius.Button),
						}),
					},

					[OnEvent("Activated")] = function()
						statement.setProperty(
							entry.BlockId,
							property.Name,
							if isActive then nil else option
						)
					end,
				})
			end
		elseif primary == "string" then
			local box = scope:New("TextBox")({
				LayoutOrder = order * 10 + 1,
				Size = UDim2.new(1, -4, 0, 22),
				BackgroundColor3 = Theme.Colors.SurfaceAlt,
				BorderSizePixel = 0,
				ClearTextOnFocus = false,
				MultiLine = true,
				Text = if isSet then tostring(raw) else "",
				PlaceholderText = if isSet then "" else tostring(property.Default or "—"),
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
						PaddingTop = UDim.new(0, Theme.Spacing.Tiny),
					}),
				},
			})

			table.insert(
				scope,
				box.FocusLost:Connect(function()
					statement.setProperty(
						entry.BlockId,
						property.Name,
						if box.Text == "" then nil else box.Text
					)
				end)
			)

			children.Control = box
		elseif AXES[primary] ~= nil then
			--- Многокомпонентный тип раскладывается в ряд полей. Правка любого поля
			--- собирает значение заново из всех компонентов: иначе запись числа в
			--- `Size` превратила бы `Vector3` в число, и валидатор отверг бы блок.
			local axes = AXES[primary]
			local current = components(if isSet then raw else property.Default, primary)
			local fieldChildren = {
				Layout = scope:New("UIListLayout")({
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, Theme.Spacing.Tiny),
				}),
			}

			for index, axis in axes do
				fieldChildren[axis] = numberField(index, axis, current[index], function(newValue)
					local parts = table.clone(current)
					parts[index] = newValue
					current = parts
					statement.setProperty(entry.BlockId, property.Name, buildValue(primary, parts))
				end)
			end

			children.Control = scope:New("Frame")({
				LayoutOrder = order * 10 + 1,
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,

				[Children] = fieldChildren,
			})
		else
			local value = if isSet then tonumber(raw) or 0 else (tonumber(property.Default) or 0)
			children.Control = numberField(order * 10 + 1, property.Name, value, function(newValue)
				local clamped = newValue
				if property.Min ~= nil then clamped = math.max(property.Min, clamped) end
				if property.Max ~= nil then clamped = math.min(property.Max, clamped) end
				if property.Step ~= nil and property.Step > 0 then
					local base = property.Min or 0
					clamped = base + math.floor((clamped - base) / property.Step) * property.Step
				end

				statement.setProperty(entry.BlockId, property.Name, clamped)
			end)
		end

		return children
	end

	--- Форма блока: собственные свойства по группам, затем секция `Block` с её
	--- скрытыми дефолтами (§2.7, §10). Секция `Block` всегда развёрнута, остальные
	--- группы сворачиваются, пока пусты.
	--- Форма блока описывается данными, а не инстансами: Fusion запрещает создавать
	--- инстансы внутри `Computed` — он пересчитывается лениво и чистит свой scope, и
	--- разрушенные инстансы остались бы в дереве. Поэтому `Computed` отдаёт только
	--- список секций, а инстансы строит `ForValues`.
	---
	--- Секция `Block` идёт последней и всегда: её поля — скрытые дефолты
	--- `CombatService/Hooks/Block.luau:24-29`, которые иначе не видно (§2.7).
	local form = scope:Computed(function(use)
		local current = use(selected)
		if current == nil then return { { Kind = "Empty" } } end

		local block = current.Block
		local definition = registry.get(block.Type)
		if definition == nil then return { { Kind = "Empty" } } end

		local sections = {}
		local grouped = {}
		local groupOrder = {}

		for _, property in definition.Properties do
			local group = property.Group
			if group == nil then
				table.insert(
					sections,
					{ Title = "Свойства", Properties = { property }, Block = block }
				)
			else
				if grouped[group] == nil then
					grouped[group] = {}
					table.insert(groupOrder, group)
				end
				table.insert(grouped[group], property)
			end
		end

		for _, group in groupOrder do
			table.insert(sections, { Title = group, Properties = grouped[group], Block = block })
		end

		local blockGroup = registry.getGroup(block.Type, "Block")
		if #blockGroup > 0 then
			table.insert(
				sections,
				{ Title = "Block", Properties = blockGroup, Block = block, IsBlock = true }
			)
		end

		return sections
	end)

	local header = scope:Computed(function(use)
		local current = use(selected)
		if current == nil then return "" end
		return `{current.Block.Type}  ·  {current.Block.Id}`
	end)

	return scope:New("ScrollingFrame")({
		Name = "PropertiesPanel",
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
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = header,
				TextColor3 = Theme.Colors.Accent,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Font,
			}),

			Sections = scope:ForValues(form, function(use, sectionScope, section)
				if section.Kind == "Empty" then
					return sectionScope:New("TextLabel")({
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, 20),
						BackgroundTransparency = 1,
						Text = "Блок не выбран",
						TextColor3 = Theme.Colors.TextMuted,
						TextSize = 11,
						Font = Theme.Font,
					})
				end

				local sectionChildren = {
					Title = sectionScope:New("TextLabel")({
						LayoutOrder = 0,
						Size = UDim2.new(1, 0, 0, 18),
						BackgroundTransparency = 1,
						Text = section.Title,
						TextColor3 = if section.IsBlock
							then Theme.Colors.Accent
							else Theme.Colors.TextMuted,
						TextSize = 11,
						TextXAlignment = Enum.TextXAlignment.Left,
						Font = Theme.Font,
					}),

					Layout = sectionScope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, Theme.Spacing.Tiny),
					}),
				}

				for rowIndex, property in section.Properties do
					local row = propertyRow(
						sectionScope,
						{ BlockId = section.Block.Id, Block = section.Block },
						property,
						rowIndex
					)
					for key, value in row do
						sectionChildren[`{rowIndex}_{key}`] = value
					end
				end

				return sectionScope:New("Frame")({
					Name = section.Title,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,

					[Children] = sectionChildren,
				})
			end),
		},
	})
end
