return {
	Name = "addSkin",
	Aliases = { "askin" },
	Description = "Adds a skin for players",
	Group = "Admin",

	Args = {
		{
			Type = "players",
			Name = "change for",
			Description = "The players to give the skin to",
		},
		{
			Type = "ability",
			Name = "specName",
			Description = "Spec to give the skin for",
		},
		{
			Type = "string",
			Name = "skinName",
			Description = 'Skin name (quote names with spaces, e.g. "PAC Hamon")',
		},
	},
}
