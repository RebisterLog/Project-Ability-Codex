const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)

const SkillBarView = require(script.Parent.Parent.views.SkillBarView)

const controls = {
	Cooldown = 9.16,
	Bind = "G",
	Rebinding = false,
}

const story = {
	fusion = Fusion,
	controls = controls,

	story = function(props)
		const scope = props.scope
		const target = props.target

		const cooldown = props.controls.Cooldown :: Fusion.Value<number>
		const bind = props.controls.Bind :: Fusion.Value<string>
		const rebinding = props.controls.Rebinding :: Fusion.Value<boolean>

		const firstRemaining = scope:Computed(function(use)
			return math.max(use(cooldown), 0)
		end)
		const firstRatio = scope:Computed(function(use)
			return if use(cooldown) > 0 then 0.58 else 0
		end)
		const thirdRemaining = scope:Computed(function(use)
			return math.max(use(cooldown) * 0.5, 0)
		end)
		const thirdRatio = scope:Computed(function(use)
			return if use(cooldown) > 0 then 0.29 else 0
		end)

		const skills = scope:Value({
			["Spec:CircularKick"] = {
				Id = "CircularKick",
				Slot = "Spec",
				SpecName = "Standless",
				Order = 1,
				Palette = nil,
				DisplayName = "Fraid kick",
				BindLabel = bind,
				Remaining = firstRemaining,
				Ratio = firstRatio,
				Pop = scope:Value(0),
				Rebinding = rebinding,
			},
			["Spec:Counter"] = {
				Id = "Counter",
				Slot = "Spec",
				SpecName = "Standless",
				Order = 2,
				Palette = nil,
				DisplayName = "Counter",
				BindLabel = "V",
				Remaining = scope:Value(0),
				Ratio = scope:Value(0),
				Pop = scope:Value(0),
				Rebinding = scope:Value(false),
			},
			["SubSpec:ZoomPunch"] = {
				Id = "ZoomPunch",
				Slot = "SubSpec",
				SpecName = "JonathanHamon",
				Order = 3,
				Palette = nil,
				DisplayName = "Zoom Punch",
				BindLabel = "Y",
				Remaining = thirdRemaining,
				Ratio = thirdRatio,
				Pop = scope:Value(0),
				Rebinding = scope:Value(false),
			},
		})

		return scope:New("Frame")({
			Name = "SkillBarStory",
			BackgroundColor3 = Color3.fromRGB(32, 32, 32),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Parent = target,

			[Fusion.Children] = {
				SkillBarView(scope, {
					Skills = skills,
					OnHoldStart = function() end,
					OnHoldEnd = function() end,
				}),
			},
		})
	end,
}

return story
