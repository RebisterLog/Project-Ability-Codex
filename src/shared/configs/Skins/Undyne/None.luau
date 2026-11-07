const Assets = game:GetService("ReplicatedStorage").assets
const GlobalAssets = Assets.Default
const Animations = Assets.Undyne.None.Animations
const Sounds = Assets.Undyne.None.Sounds
const Models = Assets.Undyne.None.Models
const Helpers = require(script.Parent.Parent.helpers)
const idleAnimation = Helpers.idleAnimation
const movementAnimation = Helpers.movementAnimation
const actionAnimation = Helpers.actionAnimation
const sound = Helpers.sound

const None = {
	Animations = {
		-- Movement
		Idle = idleAnimation(Animations.User.Movements.Idle),
		Walk = movementAnimation(Animations.User.Movements.Walk),
		Run = movementAnimation(Animations.User.Movements.Run),
		Jump = movementAnimation(GlobalAssets.Movement.Jump),
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
		-- Barrage
		Barrage = actionAnimation(Animations.User.Barrage),
		-- Arc Spear Strike
		ArcSpearStrike = actionAnimation(Animations.User.ArcSpearStrikeStart),
		-- Wait A Little Bit
		WaitALittleBit = actionAnimation(Animations.User.WaitALittleBitStart),
	},
	Sounds = {
		-- Dash
		Dash = sound(GlobalAssets.Dash.DashSound),
		Punch1 = sound(Sounds.Punches.Punch1),
		Punch2 = sound(Sounds.Punches.Punch2),
		Punch3 = sound(Sounds.Punches.Punch3),
		Punch4 = sound(Sounds.Punches.Punch4),
		-- Grab
		Grab = sound(Sounds.GrabStart),
		Grabbed = sound(Sounds.GrabHit),
		GrabVL = sound(Sounds.GrabVoice),
		-- Barrage
		PreBarrage = sound(Sounds.PreBarrage),
		Barrage = sound(Sounds.Barrage),
		PostBarrage = sound(Sounds.PostBarrage),
		-- Arc Spear Strike
		ArcSpearStrike = sound(Sounds.ArcSpearStrikeStart),
		ArcSpearStrikeHit = sound(Sounds.ArcSpearStrikeHit),
		-- Wait A Little Bit
		WaitALittleBit = sound(Sounds.WaitALittleBitStart),
		WaitALittleBitHit = sound(Sounds.WaitALittleBitHit),
	},
	Models = {
		Spear = Models.Spear,
		-- Punches
		PunchHit = Models.PunchHit,
		-- Barrage
		Barrage = Models.Barrage,
	},

	Stats = {
		Grab = {
			AnimationOffset = CFrame.new(0, 0, -4) * CFrame.Angles(0, math.pi, 0),
			FinalFrame = 75,
		},
	},
}

return None
