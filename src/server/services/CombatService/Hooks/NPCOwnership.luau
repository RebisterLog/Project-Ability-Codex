const Players = game:GetService("Players")
const types = require(game:GetService("ServerScriptService").server.types)

return {
	Name = "NPCOwnership",
	Type = "Cast",
	Priority = 110,
	Function = function(data: types.AttackData)
		if not data.State.Success or data.State.Blocked or data.State.PerfectBlocked then
			return true
		end

		const attacker = Players:GetPlayerFromCharacter(data.Attacker.instance)
		if attacker then data.Victim:ClaimNPCNetworkOwner(attacker) end
		return true
	end,
}
