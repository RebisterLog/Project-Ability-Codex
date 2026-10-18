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
			Model = NPCFolder.DIO,
			BotCharacter = "Dio",
			Weight = 10,
		},
	},
}
