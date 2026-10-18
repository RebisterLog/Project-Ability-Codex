const ReplicatedStorage = game:GetService("ReplicatedStorage")
const NPCFolder = ReplicatedStorage.assets.NPC

return {
	RespawnTime = 10,
	MaxBots = 1,
	MinBots = 1,
	CacheBots = true,
	FightTogether = false,

	Bots = {
		{
			Model = NPCFolder.Undyne,
			BotCharacter = "Undyne",
			Weight = 10,
		},
	},
}
