local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Configuration = ServerScriptService.server.Configuration
local Configs = Configuration.ConfigsFolder.Value
local SpecsConfig = require(Configs.Specs)
local skills = ServerScriptService.server.skills

local Spec = {
	Skills = {
		["Dash"] = "~/skills/Dash",
		["Punch"] = "~/skills/Punch",
		["Block"] = '~/skills/Block',
		["Run"] = "~/skills/Run",
		["Grab"] = "~/skills/Grab",
		--
		["Footrest"] = "@Specs/Standless/Footrest",
		["Uppercut"] = "@Specs/Standless/Uppercut",
		["CircularKick"] = "~/skills/Standless/CircularKick",
	},
	
	onInit = function(self)
		
	end,
}

return Spec