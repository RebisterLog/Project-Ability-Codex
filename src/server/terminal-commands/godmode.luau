return {
	Name = "godmode",
	Aliases = { "gm" },
	Description = "God mode: the targets take every hit as if it landed, but nothing reaches their humanoid",
	Group = "Admin",

	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "The players to change god mode for",
		},
		{
			Type = "boolean",
			Name = "state",
			Description = "Turn it on or off; omit to flip the current state",
			Optional = true,
		},
	},
}
