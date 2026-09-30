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

		["Barrage"] = "~/skills/Barrage",
		["ArcSpearStrike"] = "@Specs/Undyne/ArcSpearStrike",
		["WaitALittleBit"] = "~/skills/Undyne/WaitALittleBit",
	},

	onInit = function(self: types.Spec)
		local spear = self.Data.Assets.Models["Spear"] :: Model

		if spear then
			local copy = self.Cleaner:Clone(spear)
			copy:PivotTo(self.Character.instance:GetPivot())

			local motor = Instance.new("Motor6D")
			motor.Name = "HandleMotor"
			motor.Part0 = self.Character.instance:FindFirstChild("Right Arm")
			motor.Part1 = copy:FindFirstChild("Handle")
			motor.C0 = CFrame.new(0, -1, 0)
			motor.Parent = copy

			copy.Parent = self.Character.instance
		end
	end,
}

return Spec
