return {
	Name = "changeAbility",
	Aliases = { "ca" },
	Description = "Chage players ability",
	Group = "Default",
	Args = {
		{
			Type = "players",
			Name = "change for",
			Description = "The players to change ability",
		},
		{
			Type = "ability",
			Name = "abilityName",
			Description = "Ability to give",
		},
	},
}
