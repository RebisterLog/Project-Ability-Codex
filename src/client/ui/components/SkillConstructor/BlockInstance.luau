local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.shared.packages.Fusion)
local Theme = require(script.Parent.Theme)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

--- Счётчик ошибок и предупреждений блока: рамка W1–W4 рисуется по нему, а подпись
--- `⚠ n` показывает, сколько именно претензий у блока (§10).
local function issueCount(issues: { any }, blockId: string): (number, number)
	local errors = 0
	local warnings = 0

	for _, issue in issues do
		if issue.BlockId == blockId then
			if string.sub(issue.Code, 1, 1) == "E" then
				errors += 1
			else
				warnings += 1
			end
		end
	end

	return errors, warnings
end

--- Перетаскивание плашки и растяжка `Repeat`.
---
--- Соединение `UserInputService` живёт ровно время жеста и снимается на отпускании
--- кнопки: страница остаётся смонтированной при уходе в `PlayerHUD`, и живой drag
--- продолжал бы двигать блоки на скрытой странице. Страховка через `cleanup`
--- снимает его, если страницу разобрали раньше.
local function dragHandler(
	scope: Fusion.Scope,
	statement: any,
	blockId: string,
	mode: "move" | "resize"
)
	local connection: RBXScriptConnection? = nil

	local function stop()
		if connection ~= nil then
			connection:Disconnect()
			connection = nil
		end
	end

	-- Регистрация задачи в scope: `table.insert` — единственный способ добавить
	-- cleanup в этой версии Fusion, а `scope:doCleanup` выполняет их при разборе.
	table.insert(scope, stop)

	return function(input: InputObject)
		--- Жест начинается только с настоящего нажатия. `InputBegan` на кнопке
		--- приходит и на обычном движении мыши, и без этой проверки каждое
		--- смещение курсора перезапускало бы drag с новым началом — блок стоял бы
		--- на месте при любом зуме.
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		local blueprint = statement.peekBlueprint()
		local block = statement.findBlock(blueprint, blockId)
		if block == nil then return end

		local zoom = statement.peekZoom()
		local originX = input.Position.X
		local originFrame = if mode == "resize"
			then (block.EndFrame or block.StartFrame or 0)
			else (block.StartFrame or 0)

		stop()
		connection = UserInputService.InputChanged:Connect(function(changed)
			if changed.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				stop()
				return
			end

			--- Дельта идёт в пикселях и делится на зум: иначе при зуме 8 блок
			--- уезжал бы в 8 раз дальше курсора.
			local deltaFrames = math.floor((changed.Position.X - originX) / zoom)

			if mode == "resize" then
				statement.setEndFrame(blockId, originFrame + deltaFrames)
			else
				statement.setStartFrame(blockId, originFrame + deltaFrames)
			end
		end)
	end
end

return function(scope: Fusion.Scope, props: any)
	local statement = props.Store
	local registry = statement.registry

	--- Вложенные блоки рисует тот же модуль. `require(script)` вызывается во время
	--- отрисовки, а не при загрузке: на момент загрузки модуль ещё не лежит в кэше
	--- `require`, и самостоятельный `require` увёл бы его в цикл.
	local function renderChild(childProps: any)
		return require(script)(scope, childProps)
	end

	local block = props.Block
	local blockId = block.Id
	local blockType = block.Type
	local definition = registry.get(blockType)
	local categoryColor = Theme.hexToColor3(definition and definition.Color or "#78909C")
	local zoom = props.Zoom
	local depth = props.Depth or 0
	local slots = registry.getSlots(blockType)

	local errors, warnings = issueCount(props.Issues, blockId)
	local hasIssue = errors > 0 or warnings > 0

	--- Ширина: обычный блок занимает один кадр, `Repeat` — весь диапазон. `Wait`
	--- свойств не имеет и только двигает maxFrame, но рисуется как обычный блок.
	local span = 1
	if blockType == "Repeat" and type(block.EndFrame) == "number" then
		span = math.max(1, (block.EndFrame - (block.StartFrame or 0)) + 1)
	end

	--- Потомки группируются по слотам в порядке реестра: пустые слоты не рисуются
	--- вовсе (§5, §7), иначе `ProcessAttack` всегда занимал бы семь строк.
	local slotFrames = {}
	local childCount = 0

	for _, slot in slots do
		local list = if type(block.Children) == "table" then block.Children[slot] else nil
		if type(list) == "table" and #list > 0 then
			childCount += #list

			local slotChildren = {
				SlotTitle = scope:New("TextLabel")({
					Size = UDim2.new(1, 0, 0, Theme.Metrics.SlotHeight),
					BackgroundTransparency = 1,
					Text = slot,
					TextColor3 = Theme.Colors.TextMuted,
					TextSize = 10,
					TextXAlignment = Enum.TextXAlignment.Left,
					Font = Theme.Font,
				}),
			}

			for index, child in list do
				slotChildren[`Block{index}`] = renderChild({
					Block = child,
					Store = statement,
					Zoom = zoom,
					Depth = depth + 1,
					Issues = props.Issues,
					Collapsed = props.Collapsed,
					SelectedId = props.SelectedId,
				})
			end

			table.insert(slotFrames, {
				Name = slot,
				Frame = scope:New("Frame")({
					Name = slot,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,

					[Children] = {
						Layout = scope:New("UIListLayout")({
							SortOrder = Enum.SortOrder.LayoutOrder,
							Padding = UDim.new(0, Theme.Spacing.Tiny),
						}),

						Body = slotChildren,
					},
				}),
			})
		end
	end

	local isCollapsed = props.Collapsed[blockId] == true and childCount > 0
	local caption = if definition ~= nil then definition.DisplayName else blockType

	if isCollapsed then
		caption = `{caption} · {childCount} children`
	elseif blockType == "Repeat" then
		caption = `{caption}  {block.StartFrame}–{block.EndFrame}`
	elseif depth > 0 then
		caption = `{caption}  @{block.StartFrame}`
	end

	local bodyChildren = {
		Layout = scope:New("UIListLayout")({
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, Theme.Spacing.Tiny),
		}),

		Caption = scope:New("TextLabel")({
			Size = UDim2.new(1, -10, 0, Theme.Metrics.ChipHeight - 6),
			BackgroundTransparency = 1,
			Text = caption,
			TextColor3 = Theme.Colors.Text,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Theme.Font,
		}),
	}

	for index, slotFrame in slotFrames do
		bodyChildren[`Slot{index}`] = slotFrame.Frame
	end

	if hasIssue then
		bodyChildren.Issue = scope:New("TextLabel")({
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 0),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 2),
			BackgroundTransparency = 1,
			Text = if errors > 0 then `⛔{errors}` else `⚠ {warnings}`,
			TextColor3 = if errors > 0 then Theme.Colors.Error else Theme.Colors.Warning,
			TextSize = 10,
			Font = Theme.Font,
		})
	end

	local chipChildren = {
		Stroke = scope:New("UIStroke")({
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = if hasIssue
				then Theme.Colors.WarningBorder
				elseif props.SelectedId == blockId then Theme.Colors.Accent
				else Theme.Colors.Outline,
			Thickness = if props.SelectedId == blockId or hasIssue then 2 else 1,
			Transparency = if props.SelectedId == blockId or hasIssue then 0 else 0.6,
		}),

		Body = scope:New("TextButton")({
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			AutoButtonColor = true,
			Text = "",
			Font = Theme.Font,

			[Children] = {
				Content = scope:New("Frame")({
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,

					[Children] = bodyChildren,
				}),
			},

			-- Клик выбирает блок, а по блоку с детьми — сворачивает поддерево: так
			-- длинный `ProcessAttack` не занимает пол-экрана.
			[OnEvent("Activated")] = function()
				if childCount > 0 and not isCollapsed then
					statement.toggleCollapsed(blockId)
				else
					statement.selectBlock(blockId)
				end
			end,

			-- Один обработчик на оба действия: в таблице свойств ключ `[OnEvent]`
			-- может встретиться только один раз, иначе правый клик молча затирал бы
			-- перетаскивание.
			[OnEvent("InputBegan")] = function(input: InputObject, processed: boolean)
				if input.UserInputType == Enum.UserInputType.MouseButton2 then
					-- Правая кнопка открывает меню у курсора: отдельного «режима»
					-- выбора нет, а блок всегда известен по `Id`.
					if processed then return end
					statement.selectBlock(blockId)
					statement.openContextMenu(
						blockId,
						UDim2.fromOffset(input.Position.X, input.Position.Y)
					)
					return
				end

				dragHandler(scope, statement, blockId, "move")(input)
			end,
		}),
	}

	if blockType == "Repeat" then
		chipChildren.Handle = scope:New("TextButton")({
			Size = UDim2.new(0, Theme.Metrics.HandleWidth, 1, 0),
			Position = UDim2.new(1, -Theme.Metrics.HandleWidth, 0, 0),
			BackgroundColor3 = Theme.Colors.Outline,
			BorderSizePixel = 0,
			AutoButtonColor = true,
			Text = "",
			Font = Theme.Font,

			[Children] = {
				Corner = scope:New("UICorner")({
					CornerRadius = UDim.new(0, Theme.Radius.Button),
				}),
			},

			[OnEvent("InputBegan")] = dragHandler(scope, statement, blockId, "resize"),
		})
	end

	return scope:New("Frame")({
		Name = blockId,
		--- X задаётся кадром, а не раскладкой: блок стоит там, где стоит его
		--- `StartFrame`, а строка задаёт только вертикаль. Вложенные дети уезжают
		--- вниз и вправо отступом внутри плашки родителя (§10).
		Position = UDim2.fromOffset(
			(block.StartFrame or 0) * zoom,
			Theme.Metrics.RulerHeight + (props.Row or 0) * Theme.Metrics.RowHeight
		),
		Size = UDim2.fromOffset(math.max(Theme.Metrics.ChipMinWidth, span * zoom), 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = categoryColor,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 0,
		ClipsDescendants = false,

		[Children] = chipChildren,
	})
end
