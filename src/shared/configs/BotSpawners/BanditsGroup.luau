const ReplicatedStorage = game:GetService("ReplicatedStorage")
const NPCFolder = ReplicatedStorage.assets.NPC

return {
	RespawnTime = 10,
	MaxBots = 10,
	MinBots = 5,
	CacheBots = true,
	FightTogether = true,

	Bots = {
		{
			Model = NPCFolder.Mahoti,
			BotCharacter = "BasicWarrior",
			Weight = 10,
		},
	},
}
