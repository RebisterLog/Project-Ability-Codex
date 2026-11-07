const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Configuration = ServerScriptService.server.Configuration
const Configs = Configuration.ConfigsFolder.Value
local Crane = require(ReplicatedStorage.shared.packages.Crane)
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
		const CombatService = Crane:GetService("CombatService")
		const spear = CombatService:Equip(self.Character, self.Data.Assets.Models["Spear"])
		self.Cleaner:Add(spear)
	end,
}

return Spec
