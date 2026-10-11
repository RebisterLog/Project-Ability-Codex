local Assets = game:GetService("ReplicatedStorage").assets
local GlobalAssets = Assets.Default

return {
    Movement = {
        Jump = {
		    Animation = GlobalAssets.Movement.Jump,
			Priority = Enum.AnimationPriority.Movement,
		},

		FreeFall = {
    		Animation = GlobalAssets.Movement.FreeFall,
            Priority = Enum.AnimationPriority.Core,
		},
    },
}
