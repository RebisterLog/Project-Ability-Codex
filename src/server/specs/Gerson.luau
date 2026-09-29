local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Configuration = ServerScriptService.server.Configuration
local Configs = Configuration.ConfigsFolder.Value
local SpecsConfig = require(Configs.Specs)
local skills = ServerScriptService.server.skills
local types =  require(ServerScriptService.server.types)

local Spec = {
	Skills = {
		["Dash"] = "~/skills/Dash",
		["Punch"] = "~/skills/Punch",
		["Block"] = '~/skills/Block',
		["Run"] = "~/skills/Run",
		["Grab"] = "~/skills/Grab",
		

		["ShellLaunch"] = "@Specs/Gerson/ShellLaunch",
		["Bonk"] = "@Specs/Gerson/Bonk"
	},

	onInit = function(self: types.Spec)
		local hammer = self.Data.Assets.Models["Hammer"] :: Model

		if hammer then
			local copy = self.Cleaner:Clone(hammer)
			copy:PivotTo(self.Character.instance:GetPivot())

			local motor = copy:FindFirstChildOfClass("Motor6D")
			motor.Part0 = self.Character.instance:WaitForChild("Right Arm")

			copy.Parent = self.Character.instance
		end
	end,
}

return Spec