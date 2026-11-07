const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const types = require(ServerScriptService.server.types)

const Spec = {
	Skills = {
		["Dash"] = "~/skills/Dash",
		["Punch"] = "~/skills/Punch",
		["Block"] = "~/skills/Block",
		["Run"] = "~/skills/Run",
		-- ["Grab"] = "~/skills/Grab",
		["Summon"] = "~/skills/Summon",

		["StandBarrage"] = "~/skills/StandBarrage",
		["GroundSlam"] = "@Specs/StarPlatinum/GroundSlam",
		["StarFinger"] = "@Specs/StarPlatinum/StarFinger",
		["StarStrike"] = "@Specs/StarPlatinum/StarStrike",
		["GrabSlam"] = "@Specs/StarPlatinum/GrabSlam",
	},

	onInit = function(self: types.Spec)
		const standModel = self.Cleaner:Clone(self.Data.Assets.Models.Stand)
		const stand =
			Crane:GetService("StandService"):AddStandFor(self.Character, standModel) :: types.Stand

		stand.instance:SetAttribute(
			"Idle",
			self.Data.Assets.Stand.Animations.Idle.Animation.AnimationId
		)
		stand.instance:SetAttribute(
			"Walk",
			self.Data.Assets.Stand.Animations.Walk.Animation.AnimationId
		)
		stand.instance:SetAttribute(
			"Run",
			self.Data.Assets.Stand.Animations.Run.Animation.AnimationId
		)

		if not self.Character.Player then stand:HandleMovement() end
	end,
}

return Spec
