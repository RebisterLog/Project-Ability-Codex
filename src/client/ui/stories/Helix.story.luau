--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.shared.packages.Fusion)

local Helix = require(script.Parent.Parent.utils.Helix)

local controls = {
	Size = 45,
	Speed = 2.5,
	Paused = false,
}

local story = {
	fusion = Fusion,
	controls = controls,

	story = function(props)
		local target = props.target

		local scope = Fusion.scoped(Fusion, {
			Helix = Helix,
		})
		table.insert(props.scope, function()
			Fusion.doCleanup(scope)
		end)

		local sizeControl = props.controls.Size :: Fusion.Value<number>
		local speedControl = props.controls.Speed :: Fusion.Value<number>
		local pausedControl = props.controls.Paused :: Fusion.Value<boolean>

		-- The plugin drives the controls as pixels and seconds, Helix takes a UDim2 and
		-- treats a speed of zero as paused, same as ldrs does.
		local size = scope:Computed(function(use)
			local pixels = use(sizeControl)
			return UDim2.fromOffset(pixels, pixels)
		end)

		local speed = scope:Computed(function(use)
			if use(pausedControl) then
				return 0
			end

			return use(speedControl)
		end)

		local helix = scope:Helix {
			Size = size,
			Speed = speed,
			Color = Color3.fromRGB(255, 255, 255),
		}

		local root = scope:New("Frame")({
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
