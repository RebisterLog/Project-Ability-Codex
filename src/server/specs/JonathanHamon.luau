const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Configuration = ServerScriptService.server.Configuration
const Configs = Configuration.ConfigsFolder.Value
const SpecsConfig = require(Configs.Specs)
const types = require(ServerScriptService.server.types)
const skills = ServerScriptService.server.skills

const Spec = {
	Skills = {
		["SendoHamon"] = "@Specs/JonathanHamon/SendoHamon",
	},

	onInit = function(self: types.Spec) end,
}

return Spec
