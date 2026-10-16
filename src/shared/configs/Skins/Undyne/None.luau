const Assets = game:GetService("ReplicatedStorage").assets
const GlobalAssets = Assets.Default

const Animations = Assets.Undyne.None.Animations
const Sounds = Assets.Undyne.None.Sounds
const Models = Assets.Undyne.None.Models

const None = {
	Animations = {
		-- Movement
		Idle = {
			Animation = Animations.User.Movements.Idle,
			Priority = Enum.AnimationPriority.Idle,
		},

		Walk = {
			Animation = Animations.User.Movements.Walk,
			Priority = Enum.AnimationPriority.Movement,
		},

		Run = {
			Animation = Animations.User.Movements.Run,
			Priority = Enum.AnimationPriority.Movement,
		},

		Jump = {
		    Animation = GlobalAssets.Movement.Jump,
			Priority = Enum.AnimationPriority.Movement,
		},

		-- Grab

		Grab = {
			Animation = Animations.User.GrabStart,
			Priority = Enum.AnimationPriority.Action,
		},

		GrabThrow = {
			Animation = Animations.User.GrabHit,
			Priority = Enum.AnimationPriority.Action,
		},

		GrabThrowVictim = {
			Animation = Animations.Enemy.Grab,
			Priority = Enum.AnimationPriority.Action,
		},

		-- Dash
		DashForward = {
			Animation = GlobalAssets.Dash.Forward,
			Priority = Enum.AnimationPriority.Action,
		},
		DashLeft = {
			Animation = GlobalAssets.Dash.Left,
			Priority = Enum.AnimationPriority.Action,
		},
		DashRight = {
			Animation = GlobalAssets.Dash.Right,
			Priority = Enum.AnimationPriority.Action,
		},
		DashBack = {
			Animation = GlobalAssets.Dash.Backward,
			Priority = Enum.AnimationPriority.Action,
		},

		--Punches

		Punch1 = {
			Animation = Animations.Punches.Punch1,
			Priority = Enum.AnimationPriority.Action,
		},

		Punch2 = {
			Animation = Animations.Punches.Punch2,
			Priority = Enum.AnimationPriority.Action,
		},

		Punch3 = {
			Animation = Animations.Punches.Punch3,
			Priority = Enum.AnimationPriority.Action,
		},

		Punch4 = {
			Animation = Animations.Punches.Punch4,
			Priority = Enum.AnimationPriority.Action,
		},

		Block = {
			Animation = Animations.User.Block,
			Priority = Enum.AnimationPriority.Action,
		},

		-- Barrage
		Barrage = {
			Animation = Animations.User.Barrage,
			Priority = Enum.AnimationPriority.Action,
		},

		-- Arc Spear Strike
		ArcSpearStrike = {
			Animation = Animations.User.ArcSpearStrikeStart,
			Priority = Enum.AnimationPriority.Action,
		},

		-- Wait A Little Bit
		WaitALittleBit = {
			Animation = Animations.User.WaitALittleBitStart,
			Priority = Enum.AnimationPriority.Action,
		},
	},
	Sounds = {
		Punch1 = {
			Sound = Sounds.Punches.Punch1,
			Volume = 1,
		},
		Punch2 = {
			Sound = Sounds.Punches.Punch2,
			Volume = 1,
		},
		Punch3 = {
			Sound = Sounds.Punches.Punch3,
			Volume = 1,
		},
		Punch4 = {
			Sound = Sounds.Punches.Punch4,
			Volume = 1,
		},

		-- Grab

		Grab = {
			Sound = Sounds.GrabStart,
			Volume = 1,
		},

		Grabbed = {
			Sound = Sounds.GrabHit,
			Volume = 1,
		},

		GrabVL = {
			Sound = Sounds.GrabVoice,
			Volume = 1,
		},

		-- Barrage
		PreBarrage = {
			Sound = Sounds.PreBarrage,
			Volume = 1,
		},

		Barrage = {
			Sound = Sounds.Barrage,
			Volume = 1,
		},

		PostBarrage = {
			Sound = Sounds.PostBarrage,
			Volume = 1,
		},

		-- Arc Spear Strike
		ArcSpearStrike = {
			Sound = Sounds.ArcSpearStrikeStart,
			Volume = 1,
		},

		ArcSpearStrikeHit = {
			Sound = Sounds.ArcSpearStrikeHit,
			Volume = 1,
		},

		-- Wait A Little Bit
		WaitALittleBit = {
			Sound = Sounds.WaitALittleBitStart,
			Volume = 1,
		},

		WaitALittleBitHit = {
			Sound = Sounds.WaitALittleBitHit,
			Volume = 1,
		},
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
