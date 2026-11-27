const Assets = game:GetService("ReplicatedStorage").assets
const Animations = Assets.JonathanHamon.None.Animations
const Sounds = Assets.JonathanHamon.None.Sounds
const Models = Assets.JonathanHamon.None.Models
const VFXs = Assets.JonathanHamon.None.VFXs
const Helpers = require(script.Parent.Parent.helpers)
const actionAnimation = Helpers.actionAnimation
const loopedAnimation = Helpers.loopedAnimation
const sound = Helpers.sound

const None = {
	Animations = {
		SendoHamon = actionAnimation(Animations.SendoHamon),
		YellowOverdrive = actionAnimation(Animations.YellowOverdrive),
		SilverPierce = actionAnimation(Animations.SilverPierce),
		LuckAndPluck = actionAnimation(Animations.LuckAndPluck),
		Charge = loopedAnimation(Animations.Charge),
	},
	Sounds = {
		SendoHamon = sound(Sounds.SendoHamon),
		YellowOverdrive = sound(Sounds.YellowOverdrive),
		SilverPierce = sound(Sounds.SilverPierce),
		LuckAndPluck = sound(Sounds.LuckAndPluck),
		Charge = sound(Sounds.Charge),
	},
	VFXs = {
		Charge = VFXs.Charge,
	},

	Models = {
		Sword = Models.Sword,
		SendoHamon = Models.SendoHamon,
		YellowOverdrive = Models.YellowOverdrive,
		SilverPierce = Models.SilverPierce,
	},
}

return None
