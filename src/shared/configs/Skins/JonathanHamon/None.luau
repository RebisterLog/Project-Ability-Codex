const Assets = game:GetService("ReplicatedStorage").assets
const GlobalAssets = Assets.Default
const Animations = Assets.JonathanHamon.None.Animations
const Sounds = Assets.JonathanHamon.None.Sounds
const Helpers = require(script.Parent.Parent.helpers)
const actionAnimation = Helpers.actionAnimation
const sound = Helpers.sound

const None = {
	Animations = {
		SendoHamon = actionAnimation(Animations.SendoHamon)
	},
	Sounds = {},
	Models = {},
}

return None
