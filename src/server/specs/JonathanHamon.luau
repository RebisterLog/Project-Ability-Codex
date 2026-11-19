const types = require(game:GetService("ServerScriptService").server.types)

const Spec = {
	Skills = {
		["Charge"] = "~/skills/Charge",
		["SendoHamon"] = "@Specs/JonathanHamon/SendoHamon",
		["PluckAndLuck"] = "@Specs/JonathanHamon/PluckAndLuck",
		["YellowOverdrive"] = "@Specs/JonathanHamon/YellowOverdrive",
		["SilverPierce"] = "@Specs/JonathanHamon/SilverPierce",
	},

	onInit = function(_self: types.Spec) end,
}

return Spec
