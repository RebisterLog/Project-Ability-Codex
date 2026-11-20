const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ChargeConfigs = require(ReplicatedStorage.shared.configs.Charges)
const ChargeState = require(ReplicatedStorage.shared.combat.ChargeState)

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
	HamonCharge: ChargeState.Snapshot,
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
			HamonCharge = ChargeState.Snapshot(ChargeConfigs.HamonCharge.Default),
		},
		Blocking = false,
	},
} :: PlayerDynamicData
