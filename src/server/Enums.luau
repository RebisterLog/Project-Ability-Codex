const Stun = {
	None = 0,
	Light = 10,
	Medium = 20,
	Heavy = 30,
}

return {
	IFrames = {
		Ragdoll = 10,
		Dodge = 15,
		Grab = 50,
		True = 10000,
	},

	Stun = Stun,

	StunTime = {
		ExtraLight = 0.15,
		Light = 0.5,
		Medium = 1,
		Heavy = 1.5,
		VeryHeavy = 2,
	},

	-- Keyed by the numeric Stun priorities so watchers can index it with
	-- `Enums.StunSpeed[value.Priority]` directly.
	StunSpeed = {
		[Stun.Light] = 8,
		[Stun.Medium] = 3,
		[Stun.Heavy] = 0,
	},

	Ragdoll = {
		Light = 1,
		Medium = 1.5,
		Heavy = 2,
	},

	Limb = {
		Head = "Head",
		LeftArm = "LeftArm",
		RightArm = "RightArm",
		LeftLeg = "LeftLeg",
		RightLeg = "RightLeg",
		Torso = "Torso",
	},

	CastSpeed = {
		None = 0,
		Slowed = 4,
		Medium = 8,
		Walk = 16,
		Run = 25,
		Fast = 32,
		Flash = 48,
	},
}
