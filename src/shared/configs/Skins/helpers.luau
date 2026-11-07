-- Common factories for skin config entries.
-- Keeps skin configs compact: instead of repeating
-- `Animation = anim, Priority = Enum.AnimationPriority.X` tables.

const helpers = {}

function helpers.idleAnimation(Animation: Animation)
	return {
		Animation = Animation,
		Priority = Enum.AnimationPriority.Idle,
	}
end

function helpers.movementAnimation(Animation: Animation)
	return {
		Animation = Animation,
		Priority = Enum.AnimationPriority.Movement,
	}
end

function helpers.actionAnimation(Animation: Animation)
	return {
		Animation = Animation,
		Priority = Enum.AnimationPriority.Action,
	}
end

function helpers.sound(Sound: Sound, Volume: number?)
	return {
		Sound = Sound,
		Volume = Volume or 1,
	}
end

return helpers
