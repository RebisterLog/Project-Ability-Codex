const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Configuration = ServerScriptService.server.Configuration
const Configs = Configuration.ConfigsFolder.Value
const SpecsConfig = require(Configs.Specs)
const skills = ServerScriptService.server.skills
const types = require(ServerScriptService.server.types)

const Players = game:GetService("Players")

const Spec = {
	Skills = {
		["Dash"] = "~/skills/Dash",
		["Punch"] = "~/skills/Punch",
		["Block"] = "~/skills/Block",
		["Run"] = "~/skills/Run",
		["Grab"] = "~/skills/Grab",
		["Summon"] = "~/skills/Summon",

		["StandBarrage"] = "~/skills/StandBarrage",
	},

	onInit = function(self: types.Spec)
		const standModel = self.Cleaner:Clone(self.Data.Assets.Models.Stand)
		const stand =
			Crane:GetService("StandService"):AddStandFor(self.Character, standModel) :: types.Stand

		standModel:SetAttribute(
			"Idle",
			self.Data.Assets.Stand.Animations.Idle.Animation.AnimationId
		)
		standModel:SetAttribute(
			"Walk",
			self.Data.Assets.Stand.Animations.Walk.Animation.AnimationId
		)
		standModel:SetAttribute("Run", self.Data.Assets.Stand.Animations.Run.Animation.AnimationId)

		if not self.Character.Player then stand:HandleMovement() end
	end,
}

return Spec
