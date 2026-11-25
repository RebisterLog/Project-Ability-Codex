const Assets = game:GetService("ReplicatedStorage").assets
const GlobalAssets = Assets.Default
const Animations = Assets.TheWorld.None.Animations
const Models = Assets.TheWorld.None.Models
const Sounds = Assets.TheWorld.None.Sounds
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

		-- The World skills
		StopSign = actionAnimation(Animations.User.StopSign),
		StopSignVictim = actionAnimation(Animations.User.StopSignVictim),
		MarkedKnives = actionAnimation(Animations.User.MarkedKnives),
		DistantSlamCast = actionAnimation(Animations.User.DistantSlamCast),
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

		-- The World skills
		MarkedKnivesThrow = sound(Sounds.User.MarkedKnivesThrow),
		MarkedKnivesHit = sound(Sounds.User.MarkedKnivesHit),
		DistantSlamCast = sound(Sounds.User.DistantSlamCast),
	},
	Models = {
		-- Dash
		DashEffect = GlobalAssets.Dash.DashEffect,
		-- Stand model
		Stand = Models.Stand,

		-- The World skills
		StopSignImpact = Models.StopSignImpact,
		MarkIndicator = Models.MarkIndicator,
		LegBarrageVFX = Models.LegBarrageVFX,
		LegBarrageHeavyVFX = Models.LegBarrageHeavyVFX,
		DistantSlamWarning = Models.DistantSlamWarning,
	},

	Stats = {
		Grab = {
			AnimationOffset = CFrame.new(0, 0, -4) * CFrame.Angles(0, math.pi, 0),
			FinalFrame = 30,
		},

		StopSign = { HitFrame = 50, EndFrame = 90, SignLifetime = 15 },
		LegBarrage = {
			FirstTick = 8,
			LastTick = 84,
			Interval = 4,
			FinisherFrame = 100,
			EndFrame = 115,
		},
		MarkedKnives = { SpawnFrames = { 8, 16, 24 }, EndFrame = 40 },
		DistantSlam = { WarningDuration = 1.5, StandAnimationFrames = 45, HitFrame = 20 },
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

			-- The World skills
			StopSign = actionAnimation(Animations.Stand.StopSign),
			LegBarrage = actionAnimation(Animations.Stand.LegBarrage),
			LegBarrageFinisher = actionAnimation(Animations.Stand.LegBarrageFinisher),
			MarkedKnives = actionAnimation(Animations.Stand.MarkedKnives),
			DistantSlam = actionAnimation(Animations.Stand.DistantSlam),
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

			-- The World skills
			LegBarrage = sound(Sounds.Stand.LegBarrage),
			LegBarrageHit = sound(Sounds.Stand.LegBarrageHit),
			LegBarrageVL = sound(Sounds.Stand.LegBarrageVL),
			MarkedKnives = sound(Sounds.Stand.MarkedKnives),
			DistantSlam = sound(Sounds.Stand.DistantSlam),
		},
		Models = {
			-- Stand model
			Stand = Models.Stand,
			-- Summon effect part
			Summon = Models.Summon,
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
