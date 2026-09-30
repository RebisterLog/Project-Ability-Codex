local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Chrono = require(ReplicatedStorage.shared.packages.chrono)
local Config = require(ReplicatedStorage.shared.packages.chrono.Shared.Config)

Config.SetConfig("DEFAULT_NORMAL_TICK_DISTANCE", 100)
Config.SetConfig("DEFAULT_HALF_TICK_DISTANCE", 200)
Config.SetConfig("REPLICATE_DEATHS", "PLAYER_CHARACTERS")

Config.RegisterEntityType("FAST_ENTITY", {
	TICK_RATE = 1 / 60,
	FULL_ROTATION = true,
})

Config.RegisterEntityType("SLOW_ENTITY", {
	TICK_RATE = 1 / 20,
	FULL_ROTATION = true,
})

Config.RegisterEntityType("NPC", {
	TICK_RATE = 1 / 30,
	FULL_ROTATION = true,

	NORMAL_TICK_DISTANCE = 100,
	HALF_TICK_DISTANCE = 150,
})

return Config
