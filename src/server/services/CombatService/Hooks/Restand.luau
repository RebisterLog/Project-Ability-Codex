const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const types = require(ServerScriptService.server.types)

const CombatService = Crane:GetService("CombatService")

return {
	Name = "Restand",
	Type = "Cast",
	-- Deliberately last: Damage, Knockback, Stun and Ragdoll have already
	-- applied their parameters by the time a hit breaks the state, so all of
	-- that hit's effects stay in place.
	Priority = 1,
	Function = function(Data: types.AttackData)
		const State = Data.State
		const Info = Data.Info
		const Victim = Data.Victim

		-- First damaging hit stands the victim up. The watcher keeps ragdoll on
		-- if this same hit also carried its own Ragdoll parameter.
		if State.Success and (Info.Damage or 0) > 0 then
			for _, object in table.clone(Victim.Parameters.Restand.Objects) do
				object:Destroy()
			end
		end

		if Info.Restand and State.Success then
			const restand = Victim:AddParameter("Restand", true) :: types.ParameterObject<"Restand">

			if Info.Restand.Duration then
				task.delay(Info.Restand.Duration, restand.Destroy, restand)
			end

			CombatService.Interrupted:Fire(Victim)
		end

		return true
	end,
}
