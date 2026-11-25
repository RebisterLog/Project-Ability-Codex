const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)

const PlayerHUDView = require(script.Parent.Parent.views.PlayerHUDView)

const controls = {
	Health = 50,
	MaxHealth = 100,
	DelayedHealth = 80,
	Level = 25,
	Experience = 0.75,
	DisplayName = "NicknameMaxSymbols20",
}

const story = {
	fusion = Fusion,
	controls = controls,

	story = function(props)
		const scope = props.scope
		const target = props.target

		const health = props.controls.Health :: Fusion.Value<number>
		const maxHealth = props.controls.MaxHealth :: Fusion.Value<number>
		const delayedHealth = props.controls.DelayedHealth :: Fusion.Value<number>
		const level = props.controls.Level :: Fusion.Value<number>
		const experience = props.controls.Experience :: Fusion.Value<number>
		const displayName = props.controls.DisplayName :: Fusion.Value<string>

		const healthRatio = scope:Computed(function(use)
			return math.clamp(use(health) / math.max(use(maxHealth), 1), 0, 1)
		end)

		const delayedHealthRatio = scope:Computed(function(use)
			return math.clamp(use(delayedHealth) / math.max(use(maxHealth), 1), 0, 1)
		end)

		const healthText = scope:Computed(function(use)
			return ("HP %d / %d"):format(math.ceil(use(health)), math.ceil(use(maxHealth)))
		end)

		const view = PlayerHUDView(scope, {
			DisplayName = displayName,
			Level = level,
			Experience = experience,
			HealthRatio = healthRatio,
			DelayedHealthRatio = delayedHealthRatio,
			HealthText = healthText,
		})

		return scope:New("Frame")({
			Name = "PlayerHUDStory",
			BackgroundColor3 = Color3.fromRGB(32, 32, 32),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Parent = target,

			[Fusion.Children] = {
				view,
			},
		})
	end,
}

return story
