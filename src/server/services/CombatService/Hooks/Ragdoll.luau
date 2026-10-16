const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const types = require(ServerScriptService.server.types)

const CombatService = Crane:GetService("CombatService")

return {
	Name = "Ragdoll",
	Type = "Cast",
	Priority = 89,
	Function = function(Data: types.AttackData)
		const State = Data.State
		const Info = Data.Info

		if Info.Ragdoll and State.Success then
			const ragdoll =
				Data.Victim:AddParameter("Ragdoll", true) :: types.ParameterObject<"Ragdoll">

			task.delay(Info.Ragdoll.Duration or 1, ragdoll.Destroy, ragdoll)

			CombatService.Interrupted:Fire(Data.Victim)
		end

		return true
	end,
}
