-- Discrete, regenerating ammunition shared by any skill that needs it.
-- Unlike HamonCharge this is a whole-number counter, not a decaying bar.

const Configs = {
	MarkedKnives = {
		Max = 3,
		RegenInterval = 5,
	},
}

export type AmmoId = keyof typeof Configs

return Configs
