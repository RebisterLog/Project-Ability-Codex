type SkillData = {
	ReleaseTime: number,
	Bind: Enum.KeyCode | Enum.UserInputType,
	Enable: boolean,
}

export type PlayerDynamicData = {
	Skills: {[string]: SkillData} -- [skill id]: SkillData
}

return {
	Skills = {},
} :: PlayerDynamicData
