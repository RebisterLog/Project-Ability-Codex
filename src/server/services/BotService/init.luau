--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Bot = require(script.Bot)
local BotsCharacters = require(ReplicatedStorage.shared["bot-characters"])
local CombatSnapshot = require(script.CombatSnapshot)
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Sense = require(script.Sense)
local types = require(ServerScriptService.server.types)

local BotsService = Crane:CreateService({
	Name = "BotsService",
})

function BotsService:onStart()
	self.BotConfigs = Crane:GetService("ConfigService"):Get("Bots")
	self.Bots = {} :: { [types.Character]: typeof(Bot.new()) }
	self.TickId = 0
	self.Cleaner = Crane.Buttler.new()

	local combatService = Crane:GetService("CombatService")
	CombatSnapshot:Configure({ StandService = Crane:GetService("StandService") })
	Sense:Configure({ CombatService = combatService })

	self.Cleaner:Add(RunService.Heartbeat:Connect(function(dt)
		self.TickId += 1

		local now = workspace:GetServerTimeNow()
		for _, bot in self.Bots do
			if bot.Destroyed then continue end

			bot.Navigator:Update(dt, now)
			bot:Tick(dt, self.TickId, now)
		end
	end))

	self.Cleaner:Add(combatService.Casted:Connect(function(data)
		local now = workspace:GetServerTimeNow()
		local caster = data.Caster

		for _, bot in self.Bots do
			if bot.Destroyed then continue end
			if bot.Target == caster then bot:OnIncoming(data, now) end
		end
	end))
end

function BotsService:Instance(botName: string, character: types.Character)
	local config = self.BotConfigs[botName] :: BotsCharacters.BotCharacterConfig

	if config.MaxHealth then
		character.Humanoid.MaxHealth = config.MaxHealth
		character.Humanoid.Health = config.MaxHealth
	end

	local bot = Bot.new(character, config)
	self.Bots[character] = bot

	character.Destroying:Once(function()
		self:Remove(character)
	end)

	return bot
end

function BotsService:Remove(character: types.Character)
	local bot = self.Bots[character]
	if not bot then return end

	self.Bots[character] = nil
	if not bot.Destroyed then bot:Destroy() end
end

function BotsService:GetBot(character: types.Character): typeof(Bot.new())?
	return self.Bots[character]
end

function BotsService:Create(botName: string, model: Model)
	local character = Crane:AddComponent(model, "Character")
	local bot = self:Instance(botName, character)

	return bot, character
end

return BotsService
