const ReplicatedStorage = game:GetService("ReplicatedStorage")
const UserInputService = game:GetService("UserInputService")

const BlockInstance = require(script.Parent.BlockInstance)
const Fusion = require(ReplicatedStorage.shared.packages.Fusion)
const Theme = require(script.Parent.Theme)

const Children = Fusion.Children
const OnEvent = Fusion.OnEvent
const peek = Fusion.peek

const MIN_ZOOM = 1
const MAX_ZOOM = 8

--- Ширина подписей перед ползунком зума. Раньше трек начинался с нуля, то есть
--- лежал поверх подписей, а его ширина считалась от общей — получался
--- крошечный кусок в несколько пикселей, который невозможно было ухватить.
const ZOOM_TRACK_LEFT = 540

--- Шаг линейки в кадрах. Подписи не должны налезать: при крупном зуме шаг мельче,
--- у края экрана шаг растёт.
const rulerStep = function(zoom: number): number
	if zoom >= 6 then return 15 end
	if zoom >= 3 then return 30 end
	return 60
end

return function(scope: Fusion.Scope, props: any)
	const statement = props.Store

	--- Ширина дорожки: `maxFrame` берётся из эмиттера, а не считается здесь
	--- второй раз — иначе линейка и футер могли бы разойтись (§7). К ширине
	--- добавляется запас справа, иначе блок на последнем кадре обрезался краем окна.
	const trackWidthFor = function(maxFrame: number, zoom: number): number
		const minWidth = Theme.Metrics.ChipMinWidth + Theme.Spacing.Large
		return math.max(640, maxFrame * zoom + minWidth)
	end

	--- Ширина подставляется только через `Computed`, который собирает `UDim2`
	--- целиком: состояние, вложенное внутрь `UDim2`, не применяется, поэтому
	--- `UDim2.fromOffset(trackWidth, 0)` молча давал нулевую ширину — линейка
	--- схлопывалась в ноль, дорожка не прокручивалась, а блоки уезжали в угол.
	const canvasSize = scope:Computed(function(use)
		return UDim2.fromOffset(trackWidthFor(use(statement.MaxFrame), use(statement.Zoom)), 0)
	end)

	const rulerSize = scope:Computed(function(use)
		return UDim2.fromOffset(
			trackWidthFor(use(statement.MaxFrame), use(statement.Zoom)),
			Theme.Metrics.RulerHeight
		)
	end)

	const ticks = scope:Computed(function(use)
		const zoom = use(statement.Zoom)
		const step = rulerStep(zoom)
		const count = math.ceil(use(statement.MaxFrame) / step) + 1
		const result = {}

		for index = 0, count do
			table.insert(result, { Frame = index * step, Order = index })
		end

		return result
	end)

	--- Корневые блоки: вложенные рисуются внутри родителя (§10), поэтому на
	--- дорожку попадает только верхний уровень, а `Row` задаёт вертикаль.
	const roots = scope:Computed(function(use)
		const result = {}

		for _, item in use(statement.Blocks) do
			if item.ParentId == nil then
				table.insert(result, {
					Id = item.Block.Id,
					Block = item.Block,
					Order = #result + 1,
				})
			end
		end

		return result
	end)

	--- Ошибки и предупреждения одним списком: `BlockInstance` считает рамку по
	--- `BlockId` и не обязан знать, откуда пришла претензия.
	const issues = scope:Computed(function(use)
		const result = {}
		const structural = use(statement.Structural)

		for _, issue in structural.errors do
			table.insert(result, issue)
		end
		for _, issue in structural.warnings do
			table.insert(result, issue)
		end

		return result
	end)

	--- Ползунок зума.
	---
	--- Вместо пары кнопок `+`/`-`: шаг в один пиксель на кадр бесполезен, а
	--- нажимать плюс двадцать раз, чтобы открыть диапазон, — тем более. Дорожка
	--- занимает всю шапку, ползунок перетаскивается мышью, а подпись показывает
	--- текущее значение. Жест начинается только с настоящего нажатия: `InputBegan`
	--- на кнопке приходит и на обычном движении мыши.
	local trackFrame: Frame
	local connection: RBXScriptConnection? = nil

	const applyZoomFromX = function(positionX: number)
		const left, width = trackFrame.AbsolutePosition.X, trackFrame.AbsoluteSize.X
		if width <= 0 then return end

		const fraction = math.clamp((positionX - left) / width, 0, 1)
		statement.setZoom(MIN_ZOOM + math.floor(fraction * (MAX_ZOOM - MIN_ZOOM + 0.999)))
	end

	const stopDrag = function()
		if connection ~= nil then
			connection:Disconnect()
			connection = nil
		end
	end

	table.insert(scope, stopDrag)

	const beginDrag = function(input: InputObject)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		applyZoomFromX(input.Position.X)
		stopDrag()

		connection = UserInputService.InputChanged:Connect(function(changed)
			if changed.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				stopDrag()
				return
			end

			applyZoomFromX(changed.Position.X)
		end)
	end

	--- Перемотка кадрами: playhead на дорожке и клик по линейке.
	---
	--- Раньше у playhead был только `Activated`, который сбрасывал его в ноль, а
	--- линейка не реагировала на нажатия: кадр можно было задать лишь вручную
	--- в свойствах блока. Дорожка — скролл-фрейм, поэтому экранная координата
	--- переводится в координату канваса через `CanvasPosition`, иначе после
	--- прокрутки playhead уезжал бы.
	local track: ScrollingFrame
	local playheadConnection: RBXScriptConnection? = nil

	const seekFromX = function(positionX: number)
		const canvasX = positionX - track.AbsolutePosition.X + track.CanvasPosition.X
		const zoom = math.max(1, peek(statement.Zoom))

		statement.setPlayhead(math.floor(canvasX / zoom + 0.5))
	end

	const stopPlayheadDrag = function()
		if playheadConnection ~= nil then
			playheadConnection:Disconnect()
			playheadConnection = nil
		end
	end

	table.insert(scope, stopPlayheadDrag)

	const beginPlayheadDrag = function(input: InputObject)
		if
			input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end

		stopPlayheadDrag()

		playheadConnection = UserInputService.InputChanged:Connect(function(changed)
			if changed.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				stopPlayheadDrag()
				return
			end

			seekFromX(changed.Position.X)
		end)
	end

	trackFrame = scope:New("TextButton")({
		Name = "ZoomTrack",
		LayoutOrder = 3,
		Size = UDim2.new(1, -ZOOM_TRACK_LEFT, 0, 16),
		Position = UDim2.new(0, ZOOM_TRACK_LEFT, 0, 16),
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
				Name = "ZoomFill",
				Size = scope:Computed(function(use)
					const zoom = use(statement.Zoom)
					const span = MAX_ZOOM - MIN_ZOOM + 1
					return UDim2.fromScale((zoom - MIN_ZOOM + 1) / span, 1)
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
				Name = "ZoomThumb",
				Size = UDim2.fromOffset(14, 18),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = scope:Computed(function(use)
					const zoom = use(statement.Zoom)
					const span = MAX_ZOOM - MIN_ZOOM + 1
					const fraction = (zoom - MIN_ZOOM + 0.5) / span
					return UDim2.new(math.clamp(fraction, 0, 1), 0, 0.5, 0.5)
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

		[OnEvent("InputBegan")] = beginDrag,
	})
	const slider = scope:New("Frame")({
		Name = "ZoomSlider",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,

		[Children] = {
			Label = scope:New("TextLabel")({
				LayoutOrder = 0,
				Size = UDim2.new(0, 150, 0, 14),
				Position = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use)
					return `Зум: {use(statement.Zoom)} px/кадр`
				end),
				TextColor3 = Theme.Colors.TextMuted,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Font,
			}),

			Hint = scope:New("TextLabel")({
				LayoutOrder = 1,
				Size = UDim2.new(0, 190, 0, 14),
				Position = UDim2.fromOffset(160, 0),
				BackgroundTransparency = 1,
				Text = `кадр ${MIN_ZOOM} → ${MAX_ZOOM}, тяните ползунок`,
				TextColor3 = Theme.Colors.TextMuted,
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Font,
			}),

			FrameLabel = scope:New("TextLabel")({
				LayoutOrder = 2,
				Size = UDim2.new(0, 170, 0, 14),
				Position = UDim2.fromOffset(360, 0),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use)
					return `кадр {use(statement.Playhead)} / {use(statement.MaxFrame)}`
				end),
				TextColor3 = Theme.Colors.TextMuted,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = Theme.Font,
			}),

			Track = trackFrame,
		},
	})

	track = scope:New("ScrollingFrame")({
		Size = UDim2.new(1, 0, 1, -32),
		Position = UDim2.fromOffset(0, 28),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 6,
		CanvasSize = canvasSize,

		[Children] = {
			Ruler = scope:New("TextButton")({
				Name = "Ruler",
				Size = rulerSize,
				BackgroundColor3 = Theme.Colors.SurfaceAlt,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Selectable = false,
				Text = "",
				Font = Theme.Font,
				ClipsDescendants = true,

				--- Клик по линейке перематывает на кадр под курсором: подписи
				--- расставлены по шагу `rulerStep`, поэтому линейка — единственное
				--- место в таймлайне, где кадр читается прямо, а не вычисляется.
				[OnEvent("InputBegan")] = function(input: InputObject)
					if
						input.UserInputType ~= Enum.UserInputType.MouseButton1
						and input.UserInputType ~= Enum.UserInputType.Touch
					then
						return
					end

					seekFromX(input.Position.X)
				end,

				[Children] = {
					Ticks = scope:ForValues(ticks, function(use, tickScope, tick)
						return tickScope:New("TextLabel")({
							LayoutOrder = tick.Order,
							Size = UDim2.fromOffset(52, Theme.Metrics.RulerHeight),
							Position = UDim2.fromOffset(tick.Frame * use(statement.Zoom), 0),
							BackgroundTransparency = 1,
							Text = tostring(tick.Frame),
							TextColor3 = Theme.Colors.TextMuted,
							TextSize = 10,
							TextXAlignment = Enum.TextXAlignment.Left,
							Font = Theme.Font,
						})
					end),
				},
			}),

			Blocks = scope:ForValues(roots, function(use, childScope, entry)
				return BlockInstance(childScope, {
					Block = entry.Block,
					Store = statement,
					Zoom = use(statement.Zoom),
					Row = entry.Order - 1,
					LayoutOrder = entry.Order,
					Issues = use(issues),
					Collapsed = use(statement.Collapsed),
					SelectedId = use(statement.SelectedId),
				})
			end),

			Playhead = scope:New("Frame")({
				Size = UDim2.fromOffset(2, 0),
				Position = scope:Computed(function(use)
					return UDim2.fromOffset(use(statement.Playhead) * use(statement.Zoom), 0)
				end),
				BackgroundColor3 = Theme.Colors.Accent,
				BorderSizePixel = 0,
				ZIndex = 5,

				[Children] = {
					Knob = scope:New("TextButton")({
						Size = UDim2.fromOffset(22, 18),
						AnchorPoint = Vector2.new(0.5, 1),
						Position = UDim2.fromOffset(0, Theme.Metrics.RulerHeight),
						BackgroundColor3 = Theme.Colors.Accent,
						BorderSizePixel = 0,
						AutoButtonColor = true,
						Text = "▼",
						TextColor3 = Theme.Colors.Background,
						TextSize = 10,
						Font = Theme.Font,

						[OnEvent("InputBegan")] = function(input: InputObject)
							beginPlayheadDrag(input)
							seekFromX(input.Position.X)
						end,
					}),
				},
			}),
		},
	})

	return scope:New("Frame")({
		Name = "Timeline",
		--- Смещение 0.18 — сразу за палитрой: без `Position` фрейм стоял бы в левом
		--- углу, и плашки блоков оказались бы под палитрой.
		Size = UDim2.fromScale(0.54, 1),
		Position = UDim2.fromScale(0.18, 0, 0, 0),
		BackgroundColor3 = Theme.Colors.Surface,
		BorderSizePixel = 0,

		[Children] = {
			Header = scope:New("Frame")({
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundTransparency = 1,

				[Children] = {
					Layout = scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, Theme.Spacing.Small),
					}),

					Slider = slider,
				},
			}),

			--- Линейка лежит внутри скролл-фрейма и едет вместе с дорожкой: иначе
			--- после прокрутки подписи перестали бы совпадать с блоками.
			Track = track,
		},
	})
end
