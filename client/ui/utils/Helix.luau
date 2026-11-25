const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)

const Children = Fusion.Children
const peek = Fusion.peek
type UsedAs<T> = Fusion.UsedAs<T>

--[=[
	Port of the "Helix" loader from ldrs (https://github.com/GriffinJohnston/ldrs, MIT).
	Roblox has no CSS keyframes, so the original `orbit` curve is evaluated by hand and
	the per-dot `animation-delay` phases are driven by a single RenderStepped loop.
]=]

const SLICE_COUNT = 6
const DOT_SCALE = 1 / SLICE_COUNT

const DEFAULT_SIZE = UDim2.fromOffset(45, 45)
const DEFAULT_POSITION = UDim2.fromScale(0, 0)
const DEFAULT_SPEED = 2.5
const DEFAULT_COLOR = Color3.fromRGB(0, 0, 0)

--[=[
	`--uib-a` and `--uib-b` of the original stylesheet, kept as multiples of the speed so
	that they stay correct for any `Speed`. Every slice gets its `::after` dot, and every
	slice but the first one also gets a `::before` dot, for eleven dots in total.
]=]
const PHASE_A = -1 / 2
const PHASE_B = -1 / 6

--[=[
	`{translateX / size, scale, opacity}` triplets of the original `orbit` keyframes.
	The last entry repeats the first one, so the interpolation wraps seamlessly.
]=]
const ORBIT_KEYFRAMES: { { number } } = {
	{ 0.25, 0.73684, 0.65 },
	{ 0.235, 0.684208, 0.58 },
	{ 0.182, 0.631576, 0.51 },
	{ 0.129, 0.578944, 0.44 },
	{ 0.076, 0.526312, 0.37 },
	{ 0, 0.47368, 0.3 },
	{ -0.076, 0.526312, 0.37 },
	{ -0.129, 0.578944, 0.44 },
	{ -0.182, 0.631576, 0.51 },
	{ -0.235, 0.684208, 0.58 },
	{ -0.25, 0.73684, 0.65 },
	{ -0.235, 0.789472, 0.72 },
	{ -0.182, 0.842104, 0.79 },
	{ -0.129, 0.894736, 0.86 },
	{ -0.076, 0.947368, 0.93 },
	{ 0, 1, 1 },
	{ 0.076, 0.947368, 0.93 },
	{ 0.129, 0.894736, 0.86 },
	{ 0.182, 0.842104, 0.79 },
	{ 0.235, 0.789472, 0.72 },
	{ 0.25, 0.73684, 0.65 },
}

const KEYFRAME_COUNT = #ORBIT_KEYFRAMES

type Dot = {
	Frame: Frame,
	CenterY: number,
	Phase: number,
}

const DOT_LAYOUT: { { CenterY: number, Phase: number } } = {}
for slice = 1, SLICE_COUNT do
	const offset = slice - 1
	const centerY = (offset + 0.5) / SLICE_COUNT

	table.insert(DOT_LAYOUT, {
		CenterY = centerY,
		Phase = PHASE_A + PHASE_B * offset,
	})

	if slice > 1 then
		table.insert(DOT_LAYOUT, {
			CenterY = centerY,
			Phase = PHASE_B * offset,
		})
	end
end

const Helix = function(
	scope: Fusion.Scope,
	props: {
		Position: UsedAs<UDim2>?,
		Size: UsedAs<UDim2>?,
		Speed: UsedAs<number>?,
		Color: UsedAs<Color3>?,
	}
): Frame
	const startKeyframe = ORBIT_KEYFRAMES[1]

	const dots: { Dot } = {}

	-- Kept flat and in DOM order on purpose: the dots share a ZIndex, so their paint
	-- order, and therefore the stacking of the lower slices over the upper ones, relies
	-- on Roblox rendering equal-ZIndex siblings in child order.
	const children = {}

	for _, layout in DOT_LAYOUT do
		const frame = scope:New("Frame")({
			Name = "Dot",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = props.Color or DEFAULT_COLOR,
			BackgroundTransparency = 1 - startKeyframe[3],
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5 + startKeyframe[1], layout.CenterY),
			Size = UDim2.fromScale(DOT_SCALE * startKeyframe[2], DOT_SCALE * startKeyframe[2]),
		})

		table.insert(dots, {
			Frame = frame,
			CenterY = layout.CenterY,
			Phase = layout.Phase,
		})

		table.insert(children, frame)
	end

	table.insert(
		children,
		scope:New("UIAspectRatioConstraint")({
			Name = "UIAspectRatioConstraint",
			AspectRatio = 1,
		})
	)

	const startTime = os.clock()

	table.insert(
		scope,
		RunService.RenderStepped:Connect(function()
			const speed = props.Speed and peek(props.Speed) or DEFAULT_SPEED
			if speed <= 0 then return end

			const elapsed = os.clock() - startTime

			for _, dot in dots do
				const progress = ((elapsed + dot.Phase * speed) % speed) / speed

				const step = progress * (KEYFRAME_COUNT - 1)
				const from = math.floor(step)
				const alpha = step - from

				const current = ORBIT_KEYFRAMES[from + 1]
				const following = ORBIT_KEYFRAMES[(from + 1) % KEYFRAME_COUNT + 1]

				const offset = current[1] + (following[1] - current[1]) * alpha
				const scale = current[2] + (following[2] - current[2]) * alpha
				const opacity = current[3] + (following[3] - current[3]) * alpha

				dot.Frame.Position = UDim2.fromScale(0.5 + offset, dot.CenterY)
				dot.Frame.Size = UDim2.fromScale(DOT_SCALE * scale, DOT_SCALE * scale)
				dot.Frame.BackgroundTransparency = 1 - opacity
			end
		end)
	)

	return scope:New("Frame")({
		Name = "Helix",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Size = props.Size or DEFAULT_SIZE,
		Position = props.Position or DEFAULT_POSITION,

		[Children] = children,
	})
end

return Helix
