const Assets = game:GetService("ReplicatedStorage").assets
const GlobalAssets = Assets.Default

const Animations = Assets.Gerson.None.Animations
const Sounds = Assets.Gerson.None.Sounds
const Models = Assets.Gerson.None.Models

const None = {
	Animations = {
		-- Movement
		Idle = {
			--Animation = Animations.User.Movements.Idle,
			Animation = Animations.User.Movements.IdleCross,
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

		-- Shell launch

		ShellLaunch = {
			Animation = Animations.User.ShellLaunch,
			Priority = Enum.AnimationPriority.Action,
		},

		-- Bonk
		Bonk = {
			Animation = Animations.User.Bonk,
			Priority = Enum.AnimationPriority.Action,
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
	},
	Sounds = {
		-- Dash
		Dash = {
			Sound = GlobalAssets.Dash.DashSound,
			Volume = 1,
		},

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

		-- Shell Launch
		ShellBounce = {
			Sound = Sounds.BounceShell,
			Volume = 0.9,
		},

		ShellSlide = {
			Sound = Sounds.ShellSlide,
			Volume = 1,
		},

		-- Bonk
		BonkSlam = {
			Sound = Sounds.BonkSlam,
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
