const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ChargeConfigs = require(ReplicatedStorage.shared.configs.Charges)
const ChargeState = require(ReplicatedStorage.shared.combat.ChargeState)

export type SpecSlot = "Spec" | "SubSpec"

type SkillData = {
	Parameters: {
		DisplayName: string,
		ReleaseTime: number,
		Bind: Enum.KeyCode | Enum.UserInputType,
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
	Ammo: { [string]: { Amount: number, Max: number, NextRegenAt: number } },
	-- Id of the skill holding the server's global cast lock, "" when idle.
	-- Lets the client refuse to predict a dash while a different skill casts.
	CastingSkill: string,
}

export type PlayerDynamicData = {
	Skills: { [SpecSlot]: { [string]: SkillData } }, -- [slot]: [skill id]: SkillData
	CharacterState: {
		Parameters: CharacterParameters,
		Blocking: boolean,
		-- True while the last landed hit is still inside the combat window.
		-- `CombatUntil` is a server timestamp so a client can expire the flag
		-- locally even if the resetting patch arrives a frame late.
		InCombat: boolean,
		CombatUntil: number,
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
			Ammo = {},
			CastingSkill = "",
		},
		Blocking = false,
		InCombat = false,
		CombatUntil = 0,
	},
} :: PlayerDynamicData
