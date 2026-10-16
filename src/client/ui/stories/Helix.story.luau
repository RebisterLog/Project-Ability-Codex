--!strict
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)

const Helix = require(script.Parent.Parent.utils.Helix)

const controls = {
	Size = 45,
	Speed = 2.5,
	Paused = false,
}

const story = {
	fusion = Fusion,
	controls = controls,

	story = function(props)
		const target = props.target

		const scope = Fusion.scoped(Fusion, {
			Helix = Helix,
		})
		table.insert(props.scope, function()
			Fusion.doCleanup(scope)
		end)

		const sizeControl = props.controls.Size :: Fusion.Value<number>
		const speedControl = props.controls.Speed :: Fusion.Value<number>
		const pausedControl = props.controls.Paused :: Fusion.Value<boolean>

		-- The plugin drives the controls as pixels and seconds, Helix takes a UDim2 and
		-- treats a speed of zero as paused, same as ldrs does.
		const size = scope:Computed(function(use)
			const pixels = use(sizeControl)
			return UDim2.fromOffset(pixels, pixels)
		end)

		const speed = scope:Computed(function(use)
			if use(pausedControl) then return 0 end

			return use(speedControl)
		end)

		const helix = scope:Helix({
			Size = size,
			Speed = speed,
			Color = Color3.fromRGB(255, 255, 255),
		})

		const root = scope:New("Frame")({
			Name = "HelixStory",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(32, 32, 32),
			BorderSizePixel = 0,
			Parent = target,

			[Fusion.Children] = { helix },
		})

		return root
	end,
}

return story
