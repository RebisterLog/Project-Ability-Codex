const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)
const Theme = require(script.Parent.Theme)

const Children = Fusion.Children
const OnEvent = Fusion.OnEvent

--- Верхняя панель: создание, очистка, переход в превью и обмен JSON.
---
--- Roblox не даёт играм доступ к буферу обмена, поэтому экспорт — это текст в
--- `ScrollingFrame` с инструкцией `Ctrl+A / Ctrl+C`, а `Copy JSON` дополнительно
--- фокусирует поле, чтобы выделение работало сразу (§10). Плагин с
--- `plugin:SetClipboard` остаётся отдельной задачей.
---
--- Раскладка — колонка: ряд кнопок, под ним панель обмена. Кнопки лежат внутри
--- своего фрейма, а не прямо в корне: при вертикальном списке в корне они
--- выносились за 40px тулбара, наезжали на рабочую область, и клик перехватывал
--- таймлайн — по кнопке нельзя было попасть.
return function(scope: Fusion.Scope, props: any)
	const statement = props.Store

	--- Кнопка тулбара. `name` обязателен: без него все кнопки остаются `TextButton`
	--- и в дереве, и в отладке, и в автотестах они неразличимы.
	const action = function(order: number, name: string, label: string, run: () -> ()): Instance
		return scope:New("TextButton")({
			Name = name,
			LayoutOrder = order,
			--- Ширина фиксированная: `AutomaticSize` внутри списка с нулевой шириной
			--- давал пустую кнопку, в которую нельзя попасть.
			Size = UDim2.fromOffset(112, Theme.MinClick),
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
					PaddingRight = UDim.new(0, Theme.Spacing.Small),
				}),
			},

			[OnEvent("Activated")] = run,
		})
	end

	--- Поле с JSON. `Active` и фокус в `Copy JSON` — требование §10: без активного
	--- поля `Ctrl+A` не выделяет текст, и копирование не работает.
	const jsonBox = function(): TextBox
		return scope:New("TextBox")({
			Size = UDim2.new(1, -8, 1, -8),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			MultiLine = true,
			ClearTextOnFocus = false,
			Text = "",
			TextColor3 = Theme.Colors.Text,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Font = Theme.Font,
			TextWrapped = false,
		}) :: TextBox
	end

	const importBox = jsonBox()
	const exportBox = jsonBox()

	const topButtons = {
		New = action(1, "New", "New", function()
			statement.reset()
		end),

		ImportJson = action(2, "ImportJson", "Import JSON", function()
			statement.setPanelVisible(true)
		end),

		ExportJson = action(3, "ExportJson", "Export JSON", function()
			statement.setPanelVisible(true)
		end),

		Clear = action(4, "Clear", "Clear", function()
			statement.reset()
		end),

		Preview = action(5, "Preview", "Preview", function()
			statement.setRightTab("Preview")
		end),

		Modified = scope:New("TextLabel")({
			LayoutOrder = 6,
			Size = UDim2.fromOffset(0, Theme.MinClick),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use)
				if use(statement.Modified) then return "● Modified" end
				return "○ Saved"
			end),
			TextColor3 = scope:Computed(function(use)
				if use(statement.Modified) then return Theme.Colors.Warning end
				return Theme.Colors.TextMuted
			end),
			TextSize = 12,
			Font = Theme.Font,
		}),

		--- `ImportError` — состояние, и его значение может быть `nil`, а Fusion не
		--- пропускает `nil` в строковые свойства: пустая строка означает «ошибки нет».
		Error = scope:New("TextLabel")({
			LayoutOrder = 7,
			Size = UDim2.fromOffset(0, Theme.MinClick),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use)
				return use(statement.ImportError) or ""
			end),
			TextColor3 = Theme.Colors.Error,
			TextSize = 11,
			Font = Theme.Font,
		}),
	}

	const panelButtons = {
		ImportHint = action(
			1,
			"ImportHint",
			"Вставьте JSON и нажмите «Применить»",
			function()
				statement.setPanelVisible(false)
			end
		),

		ExportHint = action(
			2,
			"ExportHint",
			"Ctrl+A / Ctrl+C — скопировать",
			function()
				statement.setPanelVisible(false)
			end
		),

		ApplyImport = action(3, "ApplyImport", "Применить импорт", function()
			if statement.importCurrent(importBox.Text) then statement.setPanelVisible(false) end
		end),

		CopyJson = action(4, "CopyJson", "Copy JSON", function()
			statement.setPanelVisible(false)
			task.defer(function()
				exportBox:Activate()
				exportBox:CaptureFocus()
			end)
		end),
	}

	return scope:New("Frame")({
		Name = "Toolbar",
		ClipsDescendants = true,
		--- Тулбар растёт на высоту панели обмена, и рабочая область ниже сдвигается
		--- тем же состоянием: JSON не должен перекрывать таймлайн.
		Size = scope:Computed(function(use)
			if not use(statement.panelVisible) then return UDim2.new(1, -24, 0, 40) end
			return UDim2.new(1, -24, 0, 208)
		end),
		BackgroundColor3 = Theme.Colors.Surface,
		BorderSizePixel = 0,

		[Children] = {
			Layout = scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, Theme.Spacing.Tiny),
			}),

			Padding = scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, Theme.Spacing.Small),
				PaddingRight = UDim.new(0, Theme.Spacing.Small),
				PaddingTop = UDim.new(0, Theme.Spacing.Tiny),
			}),

			Buttons = scope:New("Frame")({
				Name = "Buttons",
				LayoutOrder = 0,
				Size = UDim2.new(1, 0, 0, Theme.MinClick),
				BackgroundTransparency = 1,

				[Children] = {
					Layout = scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, Theme.Spacing.Small),
					}),

					Items = topButtons,
				},
			}),

			Panel = scope:New("Frame")({
				Name = "JsonPanel",
				LayoutOrder = 1,
				Size = UDim2.new(1, -8, 0, 160),
				Visible = statement.panelVisible,
				--- Панель импорта раскрывается поверх остального интерфейса, поэтому
				--- поднята над содержимым колонок: в этой сборке `ZIndex` абсолютный, и
				--- контейнер с большим `ZIndex` перехватывал бы клики по кнопкам панели.
				ZIndex = 20,
				BackgroundColor3 = Theme.Colors.Background,
				BorderSizePixel = 0,

				[Children] = {
					Layout = scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, Theme.Spacing.Tiny),
					}),

					Actions = scope:New("Frame")({
						Name = "Actions",
						LayoutOrder = 0,
						Size = UDim2.new(1, 0, 0, Theme.MinClick),
						BackgroundTransparency = 1,

						[Children] = {
							Layout = scope:New("UIListLayout")({
								SortOrder = Enum.SortOrder.LayoutOrder,
								FillDirection = Enum.FillDirection.Horizontal,
								Padding = UDim.new(0, Theme.Spacing.Small),
							}),

							Items = panelButtons,
						},
					}),

					--- Поля вставки и вывода показываются одновременно: пользователь
					--- видит, откуда взялся экспорт, и куда вставлять импорт.
					ImportBox = scope:New("ScrollingFrame")({
						Name = "ImportBox",
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 1, -32),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ScrollBarThickness = 4,

						[Children] = {
							Input = importBox,
						},
					}),

					ExportBox = scope:New("ScrollingFrame")({
						Name = "ExportBox",
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 1, -32),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ScrollBarThickness = 4,

						[Children] = {
							Output = scope:New("TextLabel")({
								Size = UDim2.new(1, -8, 1, -8),
								BackgroundTransparency = 1,
								Text = statement.ExportText,
								TextColor3 = Theme.Colors.Text,
								TextSize = 11,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Top,
								Font = Theme.Font,
							}),
						},
					}),
				},
			}),
		},
	})
end
