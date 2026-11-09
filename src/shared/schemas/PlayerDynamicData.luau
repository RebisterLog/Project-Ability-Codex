export type SpecSlot = "Spec" | "SubSpec"

type SkillData = {
	DisplayName: string,
	ReleaseTime: number,
	Bind: Enum.KeyCode | Enum.UserInputType,
	Enable: boolean,
}

export type CharacterParameters = {
	Stun: {
		Priority: number,
		ExpiresAt: number,
	},
	Ragdoll: boolean,
	Restrain: boolean,
	MinWalkSpeed: number,
	MaxWalkSpeed: number,
	MaxJumpPower: number,

	-- Time-based snapshot: clients derive the smooth value from these fields.
	HamonCharge: {
		Amount: number,
		LastGainAt: number,
		Filling: boolean,
		FillStartedAt: number,
		FillStartAmount: number,
		Max: number,
		FillRate: number,
		DecayRate: number,
		HoldSeconds: number,
		ExpiresAt: number,
	},
}

export type PlayerDynamicData = {
	Skills: { [SpecSlot]: { [string]: SkillData } }, -- [slot]: [skill id]: SkillData
	CharacterState: {
		Parameters: CharacterParameters,
		Blocking: boolean,
	},
}

return {
	Skills = {
		Spec = {},
		SubSpec = {},
	},
	CharacterState = {
		Parameters = {
			Stun = {
				Priority = 0,
				ExpiresAt = 0,
			},
			Ragdoll = false,
			Restrain = false,
			MinWalkSpeed = 0,
			MaxWalkSpeed = 2048,
			MaxJumpPower = 4096,

			HamonCharge = {
				Amount = 0,
				LastGainAt = 0,
				Filling = false,
				FillStartedAt = 0,
				FillStartAmount = 0,
				Max = 100,
				FillRate = 20,
				DecayRate = 10,
				HoldSeconds = 5,
				ExpiresAt = 0,
			},
		},
		Blocking = false,
	},
} :: PlayerDynamicData
