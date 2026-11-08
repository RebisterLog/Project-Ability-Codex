const Assets = game:GetService("ReplicatedStorage").assets
const GlobalAssets = Assets.Default
const NonArmedSpecs = GlobalAssets.NonArmedSpecs
const Animations = Assets.Standless.None.Animations
const Sounds = Assets.Standless.None.Sounds
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
		Run = movementAnimation(NonArmedSpecs.Animations.Run),
		Jump = movementAnimation(GlobalAssets.Movement.Jump),
		-- Grab
		Grab = actionAnimation(Animations.User.GrabStart),
		GrabThrow = actionAnimation(Animations.User.GrabHit),
		GrabThrowVictim = actionAnimation(Animations.Enemy.Grab),
		-- Dash
		DashForward = actionAnimation(GlobalAssets.Dash.Forward),
		DashLeft = {
			Animation = GlobalAssets.Dash.Left,
			Priority = Enum.AnimationPriority.Action,
			--FadeInTime = 0.2,
		},
		DashRight = actionAnimation(GlobalAssets.Dash.Right),
		DashBack = actionAnimation(GlobalAssets.Dash.Backward),
		--Punches
		Punch1 = actionAnimation(Animations.Punches.Punch1),
		Punch2 = actionAnimation(Animations.Punches.Punch2),
		Punch3 = actionAnimation(Animations.Punches.Punch3),
		Punch4 = actionAnimation(Animations.Punches.Punch4),
		Block = actionAnimation(Animations.User.Block),
		-- Skills
		Footrest = actionAnimation(Animations.User.FootrestStart),
		FootrestVictim = actionAnimation(Animations.Enemy.Footrest),
		Uppercut = actionAnimation(Animations.User.UppercutStart),
		--Circular Kick
		CircularKick = actionAnimation(Animations.User.CircularKick),
		-- Counter
		Counter = actionAnimation(Animations.User.CounterStart),
		CounterHit = actionAnimation(Animations.User.CounterHit),
		EnemyCounter = actionAnimation(Animations.Enemy.Counter),
		-- Dual Pistols
		DualPistols = actionAnimation(Animations.User.DualPistols),
		-- Knife Stab
		KnifeStab = actionAnimation(Animations.User.KnifeStab),
	},
	Sounds = {
		-- Dash
		Dash = sound(GlobalAssets.Dash.DashSound, 0.25),
		Punch1 = sound(Sounds.Punches.Punch1),
		Punch2 = sound(Sounds.Punches.Punch2),
		Punch3 = sound(Sounds.Punches.Punch3),
		Punch4 = sound(Sounds.Punches.Punch4),
		FootrestVL = sound(Sounds.FootrestVoice),
		UppercutVL = sound(Sounds.UppercutVoice),
		UppercutHit = sound(Sounds.UppercutHit),
		-- Grab
		Grab = sound(Sounds.GrabStart),
		Grabbed = sound(Sounds.GrabHit),
		GrabVL = sound(Sounds.GrabVoice),
		-- CircularKick
		CircularKick = sound(Sounds.CircularKick),
		CircularKickVL = sound(Sounds.CircularKickVoice),
		CircularKickHit = sound(Sounds.CircularKickHit),
		-- Counter
		CounterVoice = sound(Sounds.CounterVoice),
		CounterHit = sound(Sounds.CounterHit),
		-- Dual Pistols
		DualPistolsVoice = sound(Sounds.DualPistolsVoice),
		DualPistolsReload = sound(Sounds.DualPistolsReload),
		DualPistolsShot = sound(Sounds.DualPistolsShot),
		-- Knife Stab
		KnifeStab = sound(Sounds.KnifeStab),
		KnifeStabHit = sound(Sounds.KnifeStabHit),
	},
	Models = {
		-- Punche
		ArmPunchTrail = GlobalAssets.ArmPunchTrails,
		-- Uppercut
		Uppercut = Assets.Standless.None.Models.Uppercut,
		-- Uppercut Hit
		UppercutHit = Assets.Standless.None.Models.UppercutHit,
		-- Footrest
		Footrest = Assets.Standless.None.Models.Footrest,
		-- Footrest enemy drop
		FootrestVictim = Assets.Standless.None.Models.FootrestEnemy,
		-- Circular Kick
		CircularKick = Assets.Standless.None.Models.CircularKick,
		-- Circular Kick Ground hit
		CircularKickGroundHit = Assets.Standless.None.Models.CircularKickGround,
		-- Dual Pistols
		LeftPistol = Assets.Standless.None.Models.LeftPistol,
		RightPistol = Assets.Standless.None.Models.RightPistol,
		Bullet = Assets.Standless.None.Models.Bullet,
		PistolShotEffectPart = Assets.Standless.None.Models.PistolShotEffectPart,
		-- Knife Stab
		Knife = Assets.Standless.None.Models.Knife,
		KnifeStabHit = Assets.Standless.None.Models.KnifeStabHit,
	},

	Stats = {
		Grab = {
			AnimationOffset = CFrame.new(0, 0, -4) * CFrame.Angles(0, math.pi, 0),
			FinalFrame = 30,
		},
		Counter = {
			AnimationOffset = CFrame.new(0, 0, -4) * CFrame.Angles(0, math.pi, 0),
			StartHitFrame = 30,
			FinalFrame = 45,
		},
	},
}

return None
