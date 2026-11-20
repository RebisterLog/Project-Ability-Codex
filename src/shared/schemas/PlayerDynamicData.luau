const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Hamon = require(ReplicatedStorage.shared.schemas.Hamon)

export type SpecSlot = "Spec" | "SubSpec"

type SkillData = {
	Parameters: {
		DisplayName: string,
		ReleaseTime: number,
		Bind: Enum.KeyCode | Enum.UserInputType,
		-- Replicated from the spec config: the skill should be re-requested
		-- while its key stays down. See BindService.
		Hold: boolean,
		Enabled: boolean,
	},
}

export type CharacterParameters = {
	Stun: {
		Priority: number,
		ExpiresAt: number,
	},
	Ragdoll: boolean,
	Restand: boolean,
	Restrain: boolean,
	MinWalkSpeed: number,
	MaxWalkSpeed: number,
	MaxJumpPower: number,
	HamonCharge: Hamon.HamonSnapshot,
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
			Restand = false,
			Restrain = false,
			MinWalkSpeed = 0,
			MaxWalkSpeed = 2048,
			MaxJumpPower = 4096,
			HamonCharge = Hamon.snapshot(Hamon.Default),
		},
		Blocking = false,
	},
} :: PlayerDynamicData
