local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Configuration = ServerScriptService.server.Configuration
local Configs = Configuration.ConfigsFolder.Value
local SpecsConfig = require(Configs.Specs)
local skills = ServerScriptService.server.skills
local types = require(ServerScriptService.server.types)

local Players = game:GetService("Players")

local Spec = {
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
		local standModel = self.Cleaner:Clone(self.Data.Assets.Models.Stand)
		local stand =
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
