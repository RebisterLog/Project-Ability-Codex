local Assets = game:GetService("ReplicatedStorage").assets
local GlobalAssets = Assets.Default
local NonArmedSpecs = GlobalAssets.NonArmedSpecs

local Animations = Assets.Standless.None.Animations
local Sounds =  Assets.Standless.None.Sounds

local None = {
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
			Animation =  NonArmedSpecs.Animations.Run,
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
			--FadeInTime = 0.2,
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
			Priority = Enum.AnimationPriority.Action
		},
		
		Punch2 = {
			Animation = Animations.Punches.Punch2,
			Priority = Enum.AnimationPriority.Action
		},
		
		Punch3 = {
			Animation = Animations.Punches.Punch3,
			Priority = Enum.AnimationPriority.Action
		},
		
		Punch4 = {
			Animation = Animations.Punches.Punch4,
			Priority = Enum.AnimationPriority.Action
		},
		
		Block = {
			Animation = Animations.User.Block,
			Priority = Enum.AnimationPriority.Action
		},
		
		-- Skills
		
		Footrest = {
			Animation = Animations.User.FootrestStart,
			Priority = Enum.AnimationPriority.Action
		},
		FootrestVictim = {
			Animation = Animations.Enemy.Footrest,
			Priority = Enum.AnimationPriority.Action
		},
		
		Uppercut = {
			Animation = Animations.User.UppercutStart,
			Priority = Enum.AnimationPriority.Action
		},

		--Circular Kick
		CircularKick = {
			Animation = Animations.User.CircularKick,
			Priority = Enum.AnimationPriority.Action
		},
	},
	Sounds = {
		Punch1 = {
			Sound = Sounds.Punches.Punch1,
			Volume = 1
		},
		Punch2 = {
			Sound = Sounds.Punches.Punch2,
			Volume = 1
		},
		Punch3 = {
			Sound = Sounds.Punches.Punch3,
			Volume = 1
		},
		Punch4 = {
			Sound = Sounds.Punches.Punch4,
			Volume = 1
		},
		
		FootrestVL = {
			Sound = Sounds.FootrestVoice,
			Volume = 1
		},
		
		UppercutVL = {
			Sound = Sounds.UppercutVoice,
			Volume = 1
		},
		UppercutHit = {
			Sound = Sounds.UppercutHit,
			Volume = 1
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
		
		-- CircularKick
		CircularKick = {
			Sound = Sounds.CircularKick,
			Volume = 1
		},

		CircularKickVL = {
			Sound = Sounds.CircularKickVoice,
			Volume = 1,
		},
		
		CircularKickHit = {
			Sound = Sounds.CircularKickHit,
			Volume = 1
		},
	},
	Models = {
		
		-- Punches
		PunchHit = GlobalAssets.HandledPunchHit,
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
	},
	
	Stats = {
		Grab = {
			AnimationOffset = CFrame.new(0, 0, -4) * CFrame.Angles(0, math.pi, 0),
			FinalFrame = 30,
		},
	}
}

return None