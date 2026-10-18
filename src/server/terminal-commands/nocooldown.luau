return {
	Name = "nocooldown",
	Aliases = { "nocd" },
	Description = "No cooldown: the targets' skills never sit on a cooldown",
	Group = "Admin",

	Args = {
		{
			Type = "players",
			Name = "targets",
			Description = "The players to change no cooldown for",
		},
		{
			Type = "boolean",
			Name = "state",
			Description = "Turn it on or off; omit to flip the current state",
			Optional = true,
		},
	},
}
