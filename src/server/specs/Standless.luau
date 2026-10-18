const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Configuration = ServerScriptService.server.Configuration
const Configs = Configuration.ConfigsFolder.Value
const SpecsConfig = require(Configs.Specs)
const types = require(ServerScriptService.server.types)
const skills = ServerScriptService.server.skills

const Spec = {
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
		["Counter"] = "@Specs/Standless/Counter",
		["DualPistols"] = "@Specs/Standless/DualPistols",
		["KnifeStab"] = "@Specs/Standless/KnifeStab",
	},

	onInit = function(self: types.Spec)
		const punchTrail = self.Data.Assets.Models["ArmPunchTrail"]

		const leftTrail = self.Cleaner:Clone(punchTrail)
		const rightTrail = self.Cleaner:Clone(punchTrail)

		leftTrail.Parent = self.Character.instance:FindFirstChild("Left Arm")
		rightTrail.Parent = self.Character.instance:FindFirstChild("Right Arm")
	end,
}

return Spec
