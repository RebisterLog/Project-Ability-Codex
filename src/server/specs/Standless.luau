local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Configuration = ServerScriptService.server.Configuration
local Configs = Configuration.ConfigsFolder.Value
local SpecsConfig = require(Configs.Specs)
local types = require(ServerScriptService.server.types)
local skills = ServerScriptService.server.skills

local Spec = {
	Skills = {
		["Dash"] = "~/skills/Dash",
		["Punch"] = "~/skills/Punch",
		["Block"] = "~/skills/Block",
		["Run"] = "~/skills/Run",
		["Grab"] = "~/skills/Grab",
		--
		["Footrest"] = "@Specs/Standless/Footrest",
		["Uppercut"] = "@Specs/Standless/Uppercut",
		["CircularKick"] = "@Specs/Standless/CircularKick",
	},

	onInit = function(self: types.Spec)
		local punchTrail = self.Data.Assets.Models["ArmPunchTrail"]

		local leftTrail = self.Cleaner:Clone(punchTrail)
		local rightTrail = self.Cleaner:Clone(punchTrail)

		leftTrail.Parent = self.Character.instance:FindFirstChild("Left Arm")
		rightTrail.Parent = self.Character.instance:FindFirstChild("Right Arm")
	end,
}

return Spec
