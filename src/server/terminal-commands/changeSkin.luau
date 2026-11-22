return {
	Name = "changeSkin",
	Aliases = { "cskin" },
	Description = "Changes the equipped skin for players",
	Group = "Default",

	Args = {
		{
			Type = "players",
			Name = "change for",
			Description = "The players to change the skin for",
		},
		{
			Type = "ability",
			Name = "specName",
			Description = "Spec that owns the skin",
		},
		{
			Type = "string",
			Name = "skinName",
			Description = 'Skin name (quote names with spaces, e.g. "PAC Hamon")',
		},
	},
}
