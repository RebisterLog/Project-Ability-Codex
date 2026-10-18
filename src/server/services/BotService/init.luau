const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])
const types = require(ServerScriptService.server.types)

const Bot = require(script.Bot)
const NavigationController = require(script.NavigationController)
const StateMachine = NavigationController.StateMachine

const Crane = require(ReplicatedStorage.shared.packages.Crane)

const rand = Random.new(tick())

const BotsService = Crane:CreateService({
	Name = "BotsService",
})

function BotsService:onStart()
	self.BotConfigs = Crane:GetService("ConfigService"):Get("Bots")

	self.Bots = {} :: { [types.Character]: typeof(Bot.new()) }
end

function BotsService:Instance(botName: string, character: types.Character)
	const config = self.BotConfigs[botName] :: BotsCharacters.BotCharacterConfig

	const bot = Bot.new(character, config)

	return bot
end

function BotsService:Remove(character: types.Character)
	if not self.Bots[character] then return end

	self.Bots[character].Cleaner:Cleanup()
end

function BotsService:Create(botName: string, model: Model)
	const character = Crane:AddComponent(model, "Character")
	const bot = self:Instance(botName, character)

	return bot, character
end

return BotsService
