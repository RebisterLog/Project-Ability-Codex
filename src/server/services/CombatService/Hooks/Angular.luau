const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const types = require(ServerScriptService.server.types)

const CombatService = Crane:GetService("CombatService")

return {
	Name = "Angular",
	Type = "Cast",
	Priority = 91,
	Function = function(Data: types.AttackData)
		const State = Data.State
		const Info = Data.Info

		const targetPlayer = Players:GetPlayerFromCharacter(Data.Victim.instance)
		const attackerPlayer = Players:GetPlayerFromCharacter(Data.Attacker.instance)

		if State.Success then
			if Info.Angular then
				const TargetPart = Data.Victim.RootPart
				const RootAttachment = TargetPart:FindFirstChildOfClass("Attachment")

				const Duration = Info.Angular.Duration or 0.1
				const Speed = Info.Angular.Speed or 1

				if targetPlayer then
					Crane:GetService("VFXService"):StartEffect({ targetPlayer }, "Angular", {
						Part = TargetPart,
						Velocity = Info.Angular.Velocity or Vector3.zero,
						Speed = Speed or 1,
						Duration = Duration or 0.2,
					})
				else
					Crane.Utils.ChangeNetworkOwner(Data.Victim.instance, attackerPlayer)

					if attackerPlayer then
						Crane:GetService("VFXService"):StartEffect({ attackerPlayer }, "Angular", {
							Part = TargetPart,
							Velocity = Info.Angular.Velocity or Vector3.zero,
							Speed = Speed or 1,
							Duration = Duration or 0.2,
						})
					else
						local AngularVelocity =
							TargetPart:FindFirstChild("AngularVelocity") :: AngularVelocity
						if not AngularVelocity then
							AngularVelocity = Instance.new("AngularVelocity")
							AngularVelocity.Name = "AngularVelocity"
							AngularVelocity.Attachment0 = RootAttachment
							AngularVelocity.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
							AngularVelocity.Parent = TargetPart
						end

						AngularVelocity.AngularVelocity = (Info.Angular.Velocity or Vector3.zero)
							* Speed
						AngularVelocity.MaxTorque = Info.Angular.MaxTorque or 100_000

						game.Debris:AddItem(AngularVelocity, Duration)
					end
				end
			end
		end
		return true
	end,
}
