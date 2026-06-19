local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])
local types = require(ServerScriptService.server.types)

local Bot = require(script.Bot)
local NavigationController = require(script.NavigationController)
local StateMachine = NavigationController.StateMachine

local Crane = require(ReplicatedStorage.shared.packages.Crane)

local rand = Random.new(tick())

local BotsService = Crane:CreateService({
	Name = "BotsService",
})

function BotsService:onStart()
	self.BotConfigs = Crane:GetService("ConfigService"):Get("Bots")
	
	self.Bots = {} :: {[types.Character]: typeof(Bot.new())}
end

function BotsService:Instance(botName: string, character: types.Character)
	local config = self.BotConfigs[botName] :: BotsCharacters.BotCharacterConfig
	
	local bot = Bot.new(character, config)
	
	return bot
end

function BotsService:Remove(character: types.Character)
	if not self.Bots[character] then return end
	
	self.Bots[character].Cleaner:Cleanup()
end

function BotsService:Create(botName: string, model: Model)
	
end

return BotsService