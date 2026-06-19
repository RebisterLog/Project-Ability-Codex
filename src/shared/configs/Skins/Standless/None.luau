local Assets = game:GetService("ReplicatedStorage").assets
local GlobalAssets = Assets.Default

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
			Animation = Animations.User.Movements.Run,
			Priority = Enum.AnimationPriority.Movement,
		},
		
		-- Grab
		
		StandOffGrab = {
			Animation = Animations.User.GrabStart,
			Priority = Enum.AnimationPriority.Action,
		},
		
		StandOffThrow = {
			Animation = Animations.User.GrabHit,
			Priority = Enum.AnimationPriority.Action,
		},
		
		StandOffThrowVictim = {
			Animation = Animations.Enemy.Grab,
			Priority = Enum.AnimationPriority.Action,
		},
		
		StandOnGrab = {
			Animation = Animations.User.GrabStart,
			Priority = Enum.AnimationPriority.Action,
		},

		StandOnhrow = {
			Animation = Animations.User.GrabHit,
			Priority = Enum.AnimationPriority.Action,
		},

		StandOnThrowVictim = {
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
		
		StandOffGrab = {
			Sound = Sounds.GrabStart,
			Volume = 1,
		},
		
		StandOffGrabbed = {
			Sound = Sounds.GrabHit,
			Volume = 1,
		},
		
		StandOffGrabVL = {
			Sound = Sounds.GrabVoice,
			Volume = 1,
		},
	},
	Models = {
		
		-- Punches
		PunchHit = GlobalAssets.HandledPunchHit,
	},
	
	Stats = {
		Grab = {
			AnimationOffset = CFrame.new(0, 0, -4) * CFrame.Angles(0, math.pi, 0),
			StartHitFrame = 30,
			EndHitFrame = 40,
			FinalFrame = 30,
		},
	}
}

return None