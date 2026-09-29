local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Cmdr = require(ReplicatedStorage.shared.packages.Cmdr)

local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Configuration = ServerScriptService.server.Configuration

local TerminalService = Crane:CreateService({
	Name = "TerminalService",
})

function TerminalService:onStart()
	self.ConfigService = Crane:GetService("ConfigService")
	
	Cmdr:RegisterDefaultCommands()
	Cmdr.Registry:RegisterCommandsIn(Configuration.TerminalCommandsFolder.Value)
	Cmdr:RegisterHooksIn(Configuration.TerminalHooksFolder.Value)
end

return TerminalService