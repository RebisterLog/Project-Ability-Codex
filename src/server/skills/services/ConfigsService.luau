local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local SpecClass = require(ServerScriptService.server["combat-classes"].Spec)
local Specs = require(ReplicatedStorage.shared.configs.Specs)
local Configuration = ServerScriptService.server.Configuration

local ConfigsFolder = Configuration.ConfigsFolder.Value

local ConfigService = Crane:CreateService({
	Name = "ConfigService",
})
ConfigService.Configs = {}

function ConfigService:onStart()
	for i, module in ConfigsFolder:QueryDescendants("ModuleScript") do
		local config = require(module)
		self.Configs[module.Name] = table.freeze(config)
	end
end

function ConfigService:Get(name: string)
	return self.Configs[name] or require(ConfigsFolder:FindFirstChild(name))
end

return ConfigService
