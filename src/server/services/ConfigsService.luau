const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const SpecClass = require(ServerScriptService.server["combat-classes"].Spec)
const Specs = require(ReplicatedStorage.shared.configs.Specs)
const Configuration = ServerScriptService.server.Configuration

const ConfigsFolder = Configuration.ConfigsFolder.Value

const ConfigService = Crane:CreateService({
	Name = "ConfigService",
})
ConfigService.Configs = {}

function ConfigService:onStart()
	for i, module in ConfigsFolder:QueryDescendants("ModuleScript") do
		const config = require(module)
		self.Configs[module.Name] = table.freeze(config)
	end
end

function ConfigService:Get(name: string)
	return self.Configs[name] or require(ConfigsFolder:FindFirstChild(name))
end

return ConfigService
