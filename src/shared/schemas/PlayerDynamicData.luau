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
		},
		Blocking = false,
	},
} :: PlayerDynamicData
