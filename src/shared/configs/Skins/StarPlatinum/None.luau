const Assets = game:GetService("ReplicatedStorage").assets
const GlobalAssets = Assets.Default
const NonArmedSpecs = GlobalAssets.NonArmedSpecs

const Animations = Assets.StarPlatinum.None.Animations
const Models = Assets.StarPlatinum.None.Models
const Sounds = Assets.StarPlatinum.None.Sounds

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

		-- Grab

		Grab = {
			Animation = GlobalAssets.Grab.Animations.User.GrabStart,
			Priority = Enum.AnimationPriority.Action,
		},

		GrabThrow = {
			Animation = GlobalAssets.Grab.Animations.User.GrabHit,
			Priority = Enum.AnimationPriority.Action,
		},

		GrabThrowVictim = {
			Animation = GlobalAssets.Grab.Animations.Enemy.Grab,
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
			Animation = Animations.User.Punches.Punch1,
			Priority = Enum.AnimationPriority.Action,
		},

		Punch2 = {
			Animation = Animations.User.Punches.Punch2,
			Priority = Enum.AnimationPriority.Action,
		},

		Punch3 = {
			Animation = Animations.User.Punches.Punch3,
			Priority = Enum.AnimationPriority.Action,
		},

		Punch4 = {
			Animation = Animations.User.Punches.Punch4,
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
			Sound = Sounds.User.Punches.Punch1,
			Volume = 1,
		},
		Punch2 = {
			Sound = Sounds.User.Punches.Punch2,
			Volume = 1,
		},
		Punch3 = {
			Sound = Sounds.User.Punches.Punch3,
			Volume = 1,
		},
		Punch4 = {
			Sound = Sounds.User.Punches.Punch4,
			Volume = 1,
		},

		-- Grab

		Grab = {
			Sound = GlobalAssets.Grab.Sounds.GrabStart,
			Volume = 1,
		},

		GrabHit = {
			Sound = GlobalAssets.Grab.Sounds.GrabHit,
			Volume = 1,
		},

		GrabVL = {
			Sound = GlobalAssets.Grab.Sounds.GrabVoice,
			Volume = 1,
		},
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
			Idle = {
				Animation = Animations.Stand.Movements.Idle,
				Priority = Enum.AnimationPriority.Idle,
			},

			Walk = {
				Animation = Animations.Stand.Movements.Walk,
				Priority = Enum.AnimationPriority.Movement,
			},

			Run = {
				Animation = Animations.Stand.Movements.Run,
				Priority = Enum.AnimationPriority.Movement,
			},

			--Punches

			Punch1 = {
				Animation = Animations.Stand.Punches.Punch1,
				Priority = Enum.AnimationPriority.Action,
			},

			Punch2 = {
				Animation = Animations.Stand.Punches.Punch2,
				Priority = Enum.AnimationPriority.Action,
			},

			Punch3 = {
				Animation = Animations.Stand.Punches.Punch3,
				Priority = Enum.AnimationPriority.Action,
			},

			Punch4 = {
				Animation = Animations.Stand.Punches.Punch4,
				Priority = Enum.AnimationPriority.Action,
			},

			Block = {
				Animation = Animations.Stand.Block,
				Priority = Enum.AnimationPriority.Action,
			},

			-- Grab

			Grab = {
				Animation = Animations.Stand.GrabStart,
				Priority = Enum.AnimationPriority.Action,
			},

			GrabThrow = {
				Animation = Animations.Stand.GrabHit,
				Priority = Enum.AnimationPriority.Action,
			},

			GrabThrowVictim = {
				Animation = Animations.Enemy.GrabStandOn,
				Priority = Enum.AnimationPriority.Action,
			},

			-- Summon

			Summon = {
				Animation = Animations.Stand.Summon,
				Priority = Enum.AnimationPriority.Action,
			},

			Unsummon = {
				Animation = Animations.Stand.Unsummon,
				Priority = Enum.AnimationPriority.Action,
			},

			-- Barrage

			Barrage = {
				Animation = Animations.Stand.BarrageStart,
				Priority = Enum.AnimationPriority.Action,
			},
		},

		Sounds = {
			Punch1 = {
				Sound = Sounds.Stand.Punches.Punch1,
				Volume = 1,
			},
			Punch2 = {
				Sound = Sounds.Stand.Punches.Punch2,
				Volume = 1,
			},
			Punch3 = {
				Sound = Sounds.Stand.Punches.Punch3,
				Volume = 1,
			},
			Punch4 = {
				Sound = Sounds.Stand.Punches.Punch4,
				Volume = 1,
			},

			Grab = {
				Sound = Sounds.Stand.GrabStart,
				Volume = 1,
			},

			Grabbed = {
				Sound = Sounds.Stand.GrabHit,
				Volume = 1,
			},

			GrabVL = {
				Sound = Sounds.Stand.GrabVoice,
				Volume = 1,
			},

			Summon = {
				Sound = Sounds.Stand.Summon,
				Volume = 1,
			},

			SummonVL = {
				Sound = Sounds.Stand.SummonVL,
				Volume = 1,
			},

			-- Barrage

			Barrage = {
				Sound = Sounds.Stand.Barrage,
				Volume = 0.25,
			},

			BarrageHit = {
				Sound = Sounds.Stand.BarrageHeavyHit,
				Volume = 0.25,
			},

			BarrageVL = {
				Sound = Sounds.Stand.BarrageVL,
				Volume = 1,
			},
		},

		Models = {
			-- Punches
			PunchHit = GlobalAssets.HandledPunchHit,

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
