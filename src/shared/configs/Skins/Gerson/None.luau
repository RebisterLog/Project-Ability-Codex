const Assets = game:GetService("ReplicatedStorage").assets
const GlobalAssets = Assets.Default
const Animations = Assets.Gerson.None.Animations
const Sounds = Assets.Gerson.None.Sounds
const Models = Assets.Gerson.None.Models
const Helpers = require(script.Parent.Parent.helpers)
const idleAnimation = Helpers.idleAnimation
const movementAnimation = Helpers.movementAnimation
const actionAnimation = Helpers.actionAnimation
const sound = Helpers.sound

const None = {
	Animations = {
		-- Movement
		Idle = {
			--Animation = Animations.User.Movements.Idle,
			Animation = Animations.User.Movements.IdleCross,
			Priority = Enum.AnimationPriority.Idle,
		},
		Walk = movementAnimation(Animations.User.Movements.Walk),
		Run = movementAnimation(Animations.User.Movements.Run),
		-- Shell launch
		ShellLaunch = actionAnimation(Animations.User.ShellLaunch),
		-- Bonk
		Bonk = actionAnimation(Animations.User.Bonk),
		-- Grab
		Grab = actionAnimation(Animations.User.GrabStart),
		GrabThrow = actionAnimation(Animations.User.GrabHit),
		GrabThrowVictim = actionAnimation(Animations.Enemy.Grab),
		-- Dash
		DashForward = actionAnimation(GlobalAssets.Dash.Forward),
		DashLeft = actionAnimation(GlobalAssets.Dash.Left),
		DashRight = actionAnimation(GlobalAssets.Dash.Right),
		DashBack = actionAnimation(GlobalAssets.Dash.Backward),
		--Punches
		Punch1 = actionAnimation(Animations.Punches.Punch1),
		Punch2 = actionAnimation(Animations.Punches.Punch2),
		Punch3 = actionAnimation(Animations.Punches.Punch3),
		Punch4 = actionAnimation(Animations.Punches.Punch4),
		Block = actionAnimation(Animations.User.Block),
	},
	Sounds = {
		-- Dash
		Dash = sound(GlobalAssets.Dash.DashSound),
		Punch1 = sound(Sounds.Punches.Punch1),
		Punch2 = sound(Sounds.Punches.Punch2),
		Punch3 = sound(Sounds.Punches.Punch3),
		Punch4 = sound(Sounds.Punches.Punch4),
		-- Shell Launch
		ShellBounce = sound(Sounds.BounceShell, 0.9),
		ShellSlide = sound(Sounds.ShellSlide),
		-- Bonk
		BonkSlam = sound(Sounds.BonkSlam),
		-- Grab
		Grab = sound(Sounds.GrabStart),
		Grabbed = sound(Sounds.GrabHit),
		GrabVL = sound(Sounds.GrabVoice),
	},
	Models = {
		-- Punches
		PunchHit = Models.PunchHit,
		-- Shell launch
		Shell = Models.Shell,
		-- Hammer
		Hammer = Models.Hammer,
		-- Bonk
		BonkSlam = Models.BonkSlam,
	},

	Stats = {
		Grab = {
			AnimationOffset = CFrame.new(0, 0, -4) * CFrame.Angles(0, math.pi, 0),
			FinalFrame = 75,
		},
	},
}

return None
