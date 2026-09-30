local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NPCFolder = ReplicatedStorage.assets.NPC

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
