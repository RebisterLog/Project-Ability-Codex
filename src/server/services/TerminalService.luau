const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

const Cmdr = require(ReplicatedStorage.shared.packages.Cmdr)

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Configuration = ServerScriptService.server.Configuration

const TerminalService = Crane:CreateService({
	Name = "TerminalService",
})

function TerminalService:onStart()
	self.ConfigService = Crane:GetService("ConfigService")

	Cmdr:RegisterDefaultCommands()
	Cmdr.Registry:RegisterCommandsIn(ServerScriptService.server["terminal-commands"])
	Cmdr:RegisterHooksIn(ServerScriptService.server["terminal-hooks"])
end

return TerminalService
