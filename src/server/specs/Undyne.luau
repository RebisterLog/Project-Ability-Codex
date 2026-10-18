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

		["Barrage"] = "~/skills/Barrage",
		["ArcSpearStrike"] = "@Specs/Undyne/ArcSpearStrike",
		["WaitALittleBit"] = "~/skills/Undyne/WaitALittleBit",
	},

	onInit = function(self: types.Spec)
		const spear = self.Data.Assets.Models["Spear"] :: Model

		if spear then
			const copy = self.Cleaner:Clone(spear)
			copy:PivotTo(self.Character.instance:GetPivot())

			const motor = Instance.new("Motor6D")
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
