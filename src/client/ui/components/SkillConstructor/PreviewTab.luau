local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local BotCharacters = require(ReplicatedStorage.shared["bot-characters"])
local Fusion = require(ReplicatedStorage.shared.packages.Fusion)
local Registry = require(ReplicatedStorage.shared.packages.SkillConstructor.registry)
local Theme = require(script.Parent.Theme)
local Validator = require(ReplicatedStorage.shared.packages.SkillConstructor.validator)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

--- Скины и спеки лежат в `ReplicatedStorage.shared.configs`, то есть доступны с
--- клиента: blueprint никуда не отправляется, а проверки 21–23, 25–27 и W7 всё
--- равно выполняются (§9.2). Список собирается один раз при загрузке модуля:
--- конфигов мало, они статичны, а перечитывать их на каждый выбор не нужно.
local SPECS = {}
for _, specName in { "Gerson", "Standless", "TheWorld", "Undyne" } do
	local ok, module = pcall(require, ReplicatedStorage.shared.configs.Skins[specName].None)
	if ok and type(module) == "table" then
		table.insert(SPECS, { Name = specName, Assets = module })
	end
end

local TABS = { "Frames", "Scrubber", "Code", "Checks" }

--- Блок на указанном кадре для «Scrubber». Симуляция без боя: показывается ровно
--- то, что сгенерирует эмиттер, но без исполнения в `Sequencer` (§1, §10).
local function blocksAtFrame(entries: { any }, frame: number): { any }
	local result = {}

	for _, entry in entries do
		local last = entry.EndFrame or entry.Frame
		if frame >= entry.Frame and frame <= last then
			for _, block in entry.Blocks do
				local definition = Registry.get(block.Type)
				table.insert(result, {
					Id = block.Id,
					Label = if definition ~= nil then definition.DisplayName else block.Type,
					Order = #result + 1,
				})
			end
		end
	end

	return result
end

--- Проверки против живой спеки: контекст собирается из скина, выбранного в
--- селекторе, и списка тегов ботов — ровно то, что ждёт `checkAgainstSpec`.
local function checkAgainstSkins(blueprint: any, specName: string): { [string]: any }
	for _, entry in SPECS do
		if entry.Name == specName then
			local ok, issues = pcall(function()
				return Validator.checkAgainstSpec(blueprint, {
					specData = { Assets = entry.Assets },
					validTags = BotCharacters.SkillCharacters,
				})
			end)

			if ok then return issues end
			return {
				errors = { { Code = "E_SPEC", Message = tostring(issues), Path = {} } },
				warnings = {},
			}
		end
	end

	return { errors = {}, warnings = {} }
end

return function(scope: Fusion.Scope, props: any)
	local statement = props.Store

	local frameBlocks = scope:Computed(function(use)
		return blocksAtFrame(use(statement.Preview), use(statement.Playhead))
	end)

	local checks = scope:Computed(function(use)
		return checkAgainstSkins(use(statement.Blueprint), use(statement.SpecName))
	end)

	--- Проблемы приходят данными, а инстансы строит `ForValues`: Fusion запрещает
	--- создавать инстансы внутри `Computed` — он считается лениво и чистит свой
	--- scope, поэтому разрушенные элементы остались бы в дереве.
	local issueRows = scope:Computed(function(use)
		local result = use(checks)
		local rows = {}

		for _, issue in result.errors do
			table.insert(rows, { Text = `{issue.Code}: {issue.Message}`, Error = true })
		end
		for _, issue in result.warnings do
			table.insert(rows, { Text = `{issue.Code}: {issue.Message}`, Error = false })
		end
		if #rows == 0 then
			table.insert(
				rows,
				{ Text = "Ошибок и предупреждений нет", Clean = true }
			)
		end

		for index, row in rows do
			row.Order = index
		end

		return rows
	end)

	local function codeBlock(content: any, height: number, order: number): Instance
		return scope:New("Frame")({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, height),
			BackgroundTransparency = 1,

			[Children] = {
				Text = scope:New("TextLabel")({
					Size = UDim2.new(1, -8, 1, -8),
					BackgroundTransparency = 1,
					Text = content,
					TextColor3 = Theme.Colors.Text,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					Font = Theme.Font,
				}),
			},
		})
	end

	local function subTab(name: string, order: number): Instance
		return scope:New("TextButton")({
			Name = name,
			LayoutOrder = order,
			Size = UDim2.new(0.25, -2, 0, 24),
			BackgroundColor3 = scope:Computed(function(use)
				if use(statement.PreviewTab) == name then return Theme.Colors.Accent end
				return Theme.Colors.SurfaceAlt
			end),
			BorderSizePixel = 0,
			AutoButtonColor = true,
			Selectable = true,
			Text = name,
			TextColor3 = scope:Computed(function(use)
				if use(statement.PreviewTab) == name then return Theme.Colors.Background end
				return Theme.Colors.TextMuted
			end),
			TextSize = 11,
			Font = Theme.Font,

			[OnEvent("Activated")] = function()
				statement.setPreviewTab(name)
			end,
		})
	end

	local function tabVisibility(name: string)
		return scope:Computed(function(use)
			return use(statement.PreviewTab) == name
		end)
	end

	--- Ползунок кадра для `Scrubber`.
	---
	--- Без него вкладка показывала бы блоки только для текущего кадра, а
	--- перемещаться между кадрами было бы нечем: `Playhead` двигался только
	--- полем ввода. Шаг задаётся кнопками, перетаскивание — мышью, и то и
	--- другое пишет в тот же `setPlayhead`, поэтому таймлайн и превью всегда
	--- показывают один и тот же кадр.
	local scrubTrack: Frame
	local scrubConnection: RBXScriptConnection? = nil

	--- `MaxFrame` берётся из эмиттера, а не из списка блоков: последний кадр
	--- blueprint может быть меньше максимума, и ползунок не должен упираться в
	--- него раньше времени.
	local function lastFrame(): number
		return math.max(1, peek(statement.MaxFrame))
	end

	local function applyFrameFromX(positionX: number)
		local left, width = scrubTrack.AbsolutePosition.X, scrubTrack.AbsoluteSize.X
		if width <= 0 then return end

		local fraction = math.clamp((positionX - left) / width, 0, 1)
		statement.setPlayhead(math.floor(fraction * lastFrame() + 0.5))
	end

	local function stopScrub()
		if scrubConnection ~= nil then
			scrubConnection:Disconnect()
			scrubConnection = nil
		end
	end

	table.insert(scope, stopScrub)

	local function beginScrub(input: InputObject)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		applyFrameFromX(input.Position.X)
		stopScrub()

		scrubConnection = UserInputService.InputChanged:Connect(function(changed)
			if changed.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				stopScrub()
				return
			end

			applyFrameFromX(changed.Position.X)
		end)
	end

	local function stepButton(glyph: string, order: number, delta: number): Instance
		return scope:New("TextButton")({
			Name = delta < 0 and "StepBack" or "StepForward",
			LayoutOrder = order,
			Size = UDim2.new(0, 28, 0, 24),
			BackgroundColor3 = Theme.Colors.SurfaceAlt,
			BorderSizePixel = 0,
			AutoButtonColor = true,
			Selectable = true,
			Text = glyph,
			TextColor3 = Theme.Colors.Text,
			TextSize = 12,
			Font = Theme.Font,

			[OnEvent("Activated")] = function()
				statement.setPlayhead(peek(statement.Playhead) + delta)
			end,
		})
	end

	--- Дорожка создаётся присваиванием, а не ключом таблицы: `scrubTrack = ...`
	--- внутри `[Children]` — это поле таблицы, и локальная переменная оставалась
	--- `nil`, из-за чего перетаскивание падало с `attempt to index nil`.
	scrubTrack = scope:New("TextButton")({
		Name = "ScrubTrack",
		LayoutOrder = 1,
		Size = UDim2.new(1, -72, 0, 16),
		BackgroundColor3 = Theme.Colors.SurfaceAlt,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Selectable = false,
		Text = "",
		Font = Theme.Font,

		[Children] = {
			Corner = scope:New("UICorner")({
				CornerRadius = UDim.new(1, 0),
			}),

			Fill = scope:New("Frame")({
				Name = "ScrubFill",
				Size = scope:Computed(function(use)
					return UDim2.fromScale(
						math.clamp(use(statement.Playhead) / lastFrame(), 0, 1),
						1
					)
				end),
				BackgroundColor3 = Theme.Colors.Accent,
				BorderSizePixel = 0,

				[Children] = {
					FillCorner = scope:New("UICorner")({
						CornerRadius = UDim.new(1, 0),
					}),
				},
			}),

			Thumb = scope:New("Frame")({
				Name = "ScrubThumb",
				Size = UDim2.fromOffset(12, 22),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = scope:Computed(function(use)
					local fraction = math.clamp(use(statement.Playhead) / lastFrame(), 0, 1)
					return UDim2.new(fraction, 0, 0.5, 0)
				end),
				BackgroundColor3 = Theme.Colors.Accent,
				BorderSizePixel = 0,
				ZIndex = 2,

				[Children] = {
					ThumbCorner = scope:New("UICorner")({
						CornerRadius = UDim.new(1, 0),
					}),
				},
			}),
		},

		[OnEvent("InputBegan")] = beginScrub,
	})

	local scrubber = scope:New("Frame")({
		Name = "ScrubSlider",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,

		[Children] = {
			Layout = scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, Theme.Spacing.Tiny),
			}),

			Back = stepButton("◀", 0, -1),
			Track = scrubTrack,
			Forward = stepButton("▶", 2, 1),

			FrameLabel = scope:New("TextLabel")({
				LayoutOrder = 3,
				Size = UDim2.new(0, 86, 0, 16),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use)
					return `{use(statement.Playhead)} / {use(statement.MaxFrame)}`
				end),
				TextColor3 = Theme.Colors.TextMuted,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Font,
			}),
		},
	})

	local tabButtons = {}
	for index, name in TABS do
		tabButtons[index] = subTab(name, index)
	end

	local specButtons = {}
	for index, entry in SPECS do
		specButtons[index] = scope:New("TextButton")({
			Name = entry.Name,
			LayoutOrder = index,
			Size = UDim2.new(0.5, -2, 0, 24),
			BackgroundColor3 = scope:Computed(function(use)
				if use(statement.SpecName) == entry.Name then return Theme.Colors.Accent end
				return Theme.Colors.SurfaceAlt
			end),
			BorderSizePixel = 0,
			AutoButtonColor = true,
			Selectable = true,
			Text = entry.Name,
			TextColor3 = scope:Computed(function(use)
				if use(statement.SpecName) == entry.Name then return Theme.Colors.Background end
				return Theme.Colors.TextMuted
			end),
			TextSize = 11,
			Font = Theme.Font,

			[OnEvent("Activated")] = function()
				statement.setSpecName(entry.Name)
			end,
		})
	end

	return scope:New("ScrollingFrame")({
		Name = "PreviewTab",
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

			Tabs = scope:New("Frame")({
				LayoutOrder = 0,
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,

				[Children] = {
					-- `FillDirection` задан явно: у `UIListLayout` в этой сборке
					-- дефолт вертикальный, и без строки кнопки вставали столбиком,
					-- перекрывая содержимое вкладки — ползунок кадра оказывался под
					-- ними и не получал ни клика, ни перетаскивания.
					Layout = scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, Theme.Spacing.Tiny),
					}),

					Buttons = tabButtons,
				},
			}),

			--- `Frames` — таблица кадров ровно та, что уйдёт в модуль: берётся из
			--- `emitter.framesSource`, а не форматируется заново, иначе предпросмотр
			--- мог бы расходиться с файлом (§10).
			Frames = scope:New("Frame")({
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 280),
				BackgroundTransparency = 1,
				Visible = tabVisibility("Frames"),

				[Children] = {
					Code = codeBlock(statement.FramesSource, 280, 1),
				},
			}),

			Scrubber = scope:New("Frame")({
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 200),
				BackgroundTransparency = 1,
				Visible = tabVisibility("Scrubber"),

				[Children] = {
					Layout = scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, Theme.Spacing.Tiny),
					}),

					Header = scope:New("TextLabel")({
						LayoutOrder = 0,
						Size = UDim2.new(1, 0, 0, 18),
						BackgroundTransparency = 1,
						Text = `сработавшие блоки`,
						TextColor3 = Theme.Colors.TextMuted,
						TextSize = 11,
						TextXAlignment = Enum.TextXAlignment.Left,
						Font = Theme.Font,
					}),

					Slider = scrubber,

					Blocks = scope:ForValues(frameBlocks, function(use, rowScope, entry)
						return rowScope:New("TextLabel")({
							LayoutOrder = entry.Order,
							Size = UDim2.new(1, -4, 0, 18),
							BackgroundTransparency = 1,
							Text = `{entry.Order}. {entry.Label}  ({entry.Id})`,
							TextColor3 = Theme.Colors.Text,
							TextSize = 11,
							TextXAlignment = Enum.TextXAlignment.Left,
							Font = Theme.Font,
						})
					end),
				},
			}),

			Code = scope:New("Frame")({
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 340),
				BackgroundTransparency = 1,
				Visible = tabVisibility("Code"),

				[Children] = {
					Source = codeBlock(statement.Source, 340, 1),
				},
			}),

			Checks = scope:New("Frame")({
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Visible = tabVisibility("Checks"),

				[Children] = {
					Layout = scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, Theme.Spacing.Small),
					}),

					SpecPicker = scope:New("Frame")({
						LayoutOrder = 0,
						Size = UDim2.new(1, 0, 0, 24),
						BackgroundTransparency = 1,

						[Children] = {
							Layout = scope:New("UIListLayout")({
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, Theme.Spacing.Tiny),
							}),

							Buttons = specButtons,
						},
					}),

					Issues = scope:ForValues(issueRows, function(use, rowScope, row)
						return rowScope:New("TextLabel")({
							LayoutOrder = row.Order,
							Size = UDim2.new(1, -4, 0, 18),
							BackgroundTransparency = 1,
							Text = row.Text,
							TextColor3 = if row.Error
								then Theme.Colors.Error
								elseif row.Clean then Theme.Colors.Success
								else Theme.Colors.Warning,
							TextSize = 11,
							TextXAlignment = Enum.TextXAlignment.Left,
							Font = Theme.Font,
						})
					end),
				},
			}),
		},
	})
end
