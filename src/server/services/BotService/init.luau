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

	self.Bots = {} :: { [types.Character]: typeof(Bot.new()) }
end

function BotsService:Instance(botName: string, character: types.Character)
	local config = self.BotConfigs[botName] :: BotsCharacters.BotCharacterConfig
	local bot = Bot.new(character, config)

	self.Bots[character] = bot

	return bot
end

function BotsService:Remove(character: types.Character)
	const bot = self.Bots[character]
	if not bot then return end

	bot.Cleaner:Cleanup()
	self.Bots[character] = nil
end

--- Looks a bot up by its character component. Returns nil for non-bot characters
--- (e.g. a player). Used by CombatService's knockback to route a client-side
--- knockback to the player the bot is currently targeting.
function BotsService:GetBot(character: types.Character): any?
	return self.Bots[character]
end

function BotsService:Create(botName: string, model: Model)
	local character = Crane:AddComponent(model, "Character")
	local bot = self:Instance(botName, character)

	return bot, character
end

return BotsService
