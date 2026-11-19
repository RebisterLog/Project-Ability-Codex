const types = require(game:GetService("ServerScriptService").server.types)

-- Shared Hamon SubSpec. It owns the combat skills for Hamon bots (and the
-- assets the shared Charge skill resolves through `BaseSpec = "Hamon"`).
-- Non-public so it is not offered as a playable spec on its own.
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
