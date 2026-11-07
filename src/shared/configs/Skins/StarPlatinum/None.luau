const Assets = game:GetService("ReplicatedStorage").assets
const GlobalAssets = Assets.Default
const Animations = Assets.StarPlatinum.None.Animations
const Models = Assets.StarPlatinum.None.Models
const Sounds = Assets.StarPlatinum.None.Sounds
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
		-- Grab
		Grab = actionAnimation(GlobalAssets.Grab.Animations.User.GrabStart),
		GrabThrow = actionAnimation(GlobalAssets.Grab.Animations.User.GrabHit),
		GrabThrowVictim = actionAnimation(GlobalAssets.Grab.Animations.Enemy.Grab),
		-- Dash
		DashForward = actionAnimation(GlobalAssets.Dash.Forward),
		DashLeft = actionAnimation(GlobalAssets.Dash.Left),
		DashRight = actionAnimation(GlobalAssets.Dash.Right),
		DashBack = actionAnimation(GlobalAssets.Dash.Backward),
		--Punches
		Punch1 = actionAnimation(Animations.User.Punches.Punch1),
		Punch2 = actionAnimation(Animations.User.Punches.Punch2),
		Punch3 = actionAnimation(Animations.User.Punches.Punch3),
		Punch4 = actionAnimation(Animations.User.Punches.Punch4),
		Block = actionAnimation(Animations.User.Block),
	},
	Sounds = {
		-- Dash
		Dash = sound(GlobalAssets.Dash.DashSound),
		Punch1 = sound(Sounds.User.Punches.Punch1),
		Punch2 = sound(Sounds.User.Punches.Punch2),
		Punch3 = sound(Sounds.User.Punches.Punch3),
		Punch4 = sound(Sounds.User.Punches.Punch4),
		-- Grab
		Grab = sound(GlobalAssets.Grab.Sounds.GrabStart),
		GrabHit = sound(GlobalAssets.Grab.Sounds.GrabHit),
		GrabVL = sound(GlobalAssets.Grab.Sounds.GrabVoice),
	},
	Models = {
		-- Punches
		PunchHit = GlobalAssets.HandledPunchHit,
		-- Stand model
		Stand = Models.Stand,
	},
	Stats = {
		Grab = {
			AnimationOffset = CFrame.new(0, 0, -4) * CFrame.Angles(0, math.pi, 0),
			FinalFrame = 30,
		},
	},

	Stand = {
		Animations = {
			-- Movement
			Idle = idleAnimation(Animations.Stand.Movements.Idle),
			Walk = movementAnimation(Animations.Stand.Movements.Walk),
			Run = movementAnimation(Animations.Stand.Movements.Run),
			--Punches
			Punch1 = actionAnimation(Animations.Stand.Punches.Punch1),
			Punch2 = actionAnimation(Animations.Stand.Punches.Punch2),
			Punch3 = actionAnimation(Animations.Stand.Punches.Punch3),
			Punch4 = actionAnimation(Animations.Stand.Punches.Punch4),
			Block = actionAnimation(Animations.Stand.Block),
			-- Grab
			Grab = actionAnimation(Animations.Stand.GrabStart),
			GrabThrow = actionAnimation(Animations.Stand.GrabHit),
			GrabThrowVictim = actionAnimation(Animations.Enemy.GrabStandOn),
			-- Summon
			Summon = actionAnimation(Animations.Stand.Summon),
			Unsummon = actionAnimation(Animations.Stand.Unsummon),
			-- Barrage
			Barrage = actionAnimation(Animations.Stand.BarrageStart),
			-- Ground Slam
			GroundSlam = actionAnimation(Animations.Stand.GroundSlam),
			-- Grab Slam
			GrabSlamVictim = actionAnimation(Animations.Enemy.GrabSlam),
			GrabSlamStart = actionAnimation(Animations.Stand.GrabSlam),
			GrabSlam = actionAnimation(Animations.Stand.GrabSlam),
			-- Star Finger
			StarFinger = actionAnimation(Animations.Stand.StarFinger),
			-- Star Strike
			StarStrike = actionAnimation(Animations.Stand.StarStrike),
		},
		Sounds = {
			Punch1 = sound(Sounds.Stand.Punches.Punch1),
			Punch2 = sound(Sounds.Stand.Punches.Punch2),
			Punch3 = sound(Sounds.Stand.Punches.Punch3),
			Punch4 = sound(Sounds.Stand.Punches.Punch4),
			Grab = sound(Sounds.Stand.GrabStart),
			Grabbed = sound(Sounds.Stand.GrabHit),
			GrabVL = sound(Sounds.Stand.GrabVoice),
			Summon = sound(Sounds.Stand.Summon),
			SummonVL = sound(Sounds.Stand.SummonVL),
			-- Barrage
			Barrage = sound(Sounds.Stand.Barrage, 0.25),
			BarrageHit = sound(Sounds.Stand.BarrageHeavyHit, 0.25),
			BarrageVL = sound(Sounds.Stand.BarrageVL),
			-- Ground Slam
			GroundSlam = sound(Sounds.Stand.GroundSlam),
			-- Grab Slam
			GrabSlam = sound(Sounds.Stand.GrabSlam),
			GrabSlamStart = sound(Sounds.Stand.GrabSlamStart),
			-- Star Finger
			StarFinger = sound(Sounds.Stand.StarFinger),
			-- Star Strike
			StarStrike = sound(Sounds.Stand.StarStrike),
			StarStrikeHit = sound(Sounds.Stand.StarStrikeHit),
		},
		Models = {
			-- Punches
			PunchHit = GlobalAssets.HandledPunchHit,
			-- Stand model
			Stand = Models.Stand,
			-- Summon effect part
			Summon = Models.Summon,
			-- Ground slam impact (from Gerson Bonk)
			GroundImpact = Models.GroundSlam,
		},
		Stats = {
			Grab = {
				AnimationOffset = CFrame.new(0, 0, -4) * CFrame.Angles(0, math.pi, 0),
				FinalFrame = 30,
			},
		},
	},
}

return None