local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NPCFolder = ReplicatedStorage.assets.NPC

return {
	RespawnTime = 10,
	MaxBots = 1,
	MinBots = 1,
	CacheBots = true,
	FightTogether = false,
	
	Bots = {
		{
			Model = NPCFolder.Gerson,
			BotCharacter = "Gerson",
			Weight = 10,
		},
	}
}