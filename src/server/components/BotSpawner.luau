local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Proxy = require(ReplicatedStorage.shared.packages.Proxy)
local types = require(ServerScriptService.server.types)

type SpawnerBotConfig = {
	Model: Model,
	BotCharacter: string,
	Weight: number,
}

type SpawnerConfig = {
	MinBots: number,
	MaxBots: number?,
	RespawnTime: number?,
	CacheBots: boolean?,
	FightTogether: boolean?,

	Bots: {SpawnerBotConfig},
}

local BotSpawner: Crane.Component<Part> = Crane:CreateComponent({
	Name = "BotSpawner",
	Tag = "BotSpawner"
})

function BotSpawner.onStart(self: typeof(BotSpawner))
	local configName = self.instance:GetAttribute("Config")

	self.Random = Random.new(tick())
	self.Bots = {}
	self.Config = Crane:GetService("ConfigService"):Get("BotSpawners")[configName]  :: SpawnerConfig
	
	if not self.Config then
		error(`Invalid BotSpawner config: {configName}`)
	end
	
	self.instance.Anchored = true
	self.instance.Transparency = 1
	self.instance.CanCollide = false
	self.instance.CanQuery = false
	self.instance.CanTouch = false
	
	task.delay(self.Config.RespawnTime or 0, function()
		self:Spawn()
	end)
end

function BotSpawner:GetRandomBotConfig(config: SpawnerConfig)
	local bots = config.Bots
	local summ = 0

	local sorted = {}
	
	for i, bot in bots do
		summ += bot.Weight or 0
		sorted[bot.Weight] = bot
	end
	
	local random = self.Random:NextInteger(0, summ)
	
	local current = 0
	for weight, bot in sorted do
		current += weight
		
		if random <= current then
			return bot
		end
	end
	
	return bots[1]
end

function BotSpawner:Spawn()
	local botsCount = self.Random:NextInteger(self.Config.MinBots, self.Config.MaxBots or self.Config.MinBots)

	for i=1, botsCount do
		local botConfig = self:GetRandomBotConfig(self.Config)
		local model = botConfig.Model:Clone() :: Model
		model:PivotTo(self.instance.CFrame + Vector3.new(self.Random:NextNumber(0, 15), 5, self.Random:NextNumber(0, 15)))
		model.Parent = workspace.Live
		
		local bot, character: types.Character = Crane:GetService("BotsService"):Create(botConfig.BotCharacter, model)

		if self.Config.FightTogether then
			local Cleaner = Crane.Buttler.new()
			
			Cleaner:Add(character.OnTakeDamage:Once(function(attacker, data)
				for i, bot in self.Bots do
					if bot == self then continue end
					bot:SetTarget(attacker)
				end	
				
				Cleaner:Destroy()
			end))
		end
		
		character.Destroying:Once(function()
			if table.find(self.Bots, bot) then
				table.remove(self.Bots, table.find(self.Bots, bot))
			end
			
			if #self.Bots == 0 then
				task.delay(self.Config.RespawnTime or 0, function()
					self:Spawn()
				end)
			end
		end)

		table.insert(self.Bots, bot)
	end
end

return BotSpawner