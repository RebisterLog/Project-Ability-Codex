const Assets = game:GetService("ReplicatedStorage").assets
const Animations = Assets.JonathanHamon.None.Animations
const Sounds = Assets.JonathanHamon.None.Sounds
const Models = Assets.JonathanHamon.None.Models
const Helpers = require(script.Parent.Parent.helpers)
const actionAnimation = Helpers.actionAnimation
const sound = Helpers.sound

const None = {
	Animations = {
		SendoHamon = actionAnimation(Animations.SendoHamon),
		YellowOverdrive = actionAnimation(Animations.YellowOverdrive),
		SilverPierce = actionAnimation(Animations.SilverPierce),
		LuckAndPluck = actionAnimation(Animations.LuckAndPluck),
	},
	Sounds = {
		SendoHamon = sound(Sounds.SendoHamon),
		YellowOverdrive = sound(Sounds.YellowOverdrive),
		SilverPierce = sound(Sounds.SilverPierce),
		LuckAndPluck = sound(Sounds.LuckAndPluck),
	},

	Models = {
		Sword = Models.Sword,
		SendoHamon = Models.SendoHamon,
		YellowOverdrive = Models.YellowOverdrive,
	},
}

return None
