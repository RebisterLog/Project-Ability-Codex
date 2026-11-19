-- Assets for the shared Hamon skills (Charge). The Hamon SubSpec exists so the
-- shared skill can resolve its assets through `BaseSpec = "Hamon"`.
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Assets = ReplicatedStorage.assets
const Hamon = Assets.Default.Hamon
const Helpers = require(script.Parent.Parent.helpers)
const loopedAnimation = Helpers.loopedAnimation
const sound = Helpers.sound

const None = {
	Animations = {
		Charge = loopedAnimation(Hamon.Animations.Charge),
	},
	Sounds = {
		Charge = sound(Hamon.Sounds.Charge),
	},
	VFXs = {
		Charge = Hamon.VFXs.Charge,
		Hit = Hamon.VFXs.Hit,
	},
}

return None
