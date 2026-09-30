return {
	Name = "addAbility",
	Aliases = { "aa" },
	Description = "Adds ability for players",
	Group = "Admin",

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
