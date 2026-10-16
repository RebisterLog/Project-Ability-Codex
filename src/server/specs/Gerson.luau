const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Configuration = ServerScriptService.server.Configuration
const Configs = Configuration.ConfigsFolder.Value
const SpecsConfig = require(Configs.Specs)
const skills = ServerScriptService.server.skills
const types = require(ServerScriptService.server.types)

const Spec = {
	Skills = {
		["Dash"] = "~/skills/Dash",
		["Punch"] = "~/skills/Punch",
		["Block"] = "~/skills/Block",
		["Run"] = "~/skills/Run",
		["Grab"] = "~/skills/Grab",

		["ShellLaunch"] = "@Specs/Gerson/ShellLaunch",
		["Bonk"] = "@Specs/Gerson/Bonk",
	},

	onInit = function(self: types.Spec)
		const hammer = self.Data.Assets.Models["Hammer"] :: Model

		if hammer then
			const copy = self.Cleaner:Clone(hammer)
			copy:PivotTo(self.Character.instance:GetPivot())

			const motor = copy:FindFirstChildOfClass("Motor6D")
			motor.Part0 = self.Character.instance:WaitForChild("Right Arm")

			copy.Parent = self.Character.instance
		end
	end,
}

return Spec
