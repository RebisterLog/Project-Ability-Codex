const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const types = require(ServerScriptService.server.types)

const CombatService = Crane:GetService("CombatService")

return {
	Name = "Knockback",
	Type = "Cast",
	Priority = 90,
	Function = function(Data: types.AttackData)
		const State = Data.State
		const Info = Data.Info

		if State.Success then
			if Info.Knockback then
				const AttackerPart = Data.Attacker.RootPart
				const TargetPart = Data.Victim.RootPart
				local LookVector = Info.Knockback.LookVector or Vector3.zero

				const targetPlayer = Players:GetPlayerFromCharacter(Data.Victim.instance)
				const attackerPlayer = Players:GetPlayerFromCharacter(Data.Attacker.instance)

				if Info.Knockback.RelativePart == "Attacker" and AttackerPart then
					LookVector += AttackerPart.CFrame.LookVector
				elseif Info.Knockback.RelativePart == "Target" and TargetPart then
					LookVector += TargetPart.CFrame.LookVector
				end

				if Info.Knockback.RelativeTowards and AttackerPart then
					if Info.Knockback.RelativeTowards == "Target" then
						LookVector += CFrame.lookAt(AttackerPart.Position, TargetPart.Position).LookVector
					elseif Info.Knockback.RelativeTowards == "Attacker" then
						LookVector += CFrame.lookAt(TargetPart.Position, AttackerPart.Position).LookVector
					end
				end

				if Info.Knockback.Origin then
					LookVector += CFrame.lookAt(Info.Knockback.Origin.Position, TargetPart.Position).LookVector
				end

				if Info.Knockback.ToFront then
					LookVector += ((AttackerPart.Position + AttackerPart.CFrame.LookVector * Info.Knockback.ToFront or 4) - TargetPart.Position)
				end

				const Duration = Info.Knockback.Duration or 0.1
				const Speed = Info.Knockback.Speed or 1

				if targetPlayer then
					Crane:GetService("VFXService"):StartEffect({ targetPlayer }, "Knockback", {
						Part = TargetPart,
						Velocity = (
							(Info.Knockback.Velocity or Vector3.zero)
							+ ((LookVector or Vector3.zero) * Speed)
						),
						MaxForce = Info.Knockback.MaxForce
							or Vector3.new(100_000, 100_000, 100_000),
						Duration = Duration or 0.2,
					})
				else
					Crane.Utils.ChangeNetworkOwner(Data.Victim.instance, attackerPlayer)

					if attackerPlayer then
						Crane:GetService("VFXService")
							:StartEffect({ attackerPlayer }, "Knockback", {
								Part = TargetPart,
								Velocity = (
									(Info.Knockback.Velocity or Vector3.zero)
									+ ((LookVector or Vector3.zero) * Speed)
								),
								MaxForce = Info.Knockback.MaxForce
									or Vector3.new(100_000, 100_000, 100_000),
								Duration = Duration or 0.2,
							})
					else
						const BodyVelocity = Instance.new("BodyVelocity")
						BodyVelocity.P = math.huge
						BodyVelocity.Velocity = (
							(Info.Knockback.Velocity or Vector3.zero)
							+ ((LookVector or Vector3.zero) * Speed)
						)
						BodyVelocity.MaxForce = Info.Knockback.MaxForce
							or Vector3.new(100_000, 100_000, 100_000)

						BodyVelocity.Name = "KnockbackVelocity"
						BodyVelocity.Parent = TargetPart

						game.Debris:AddItem(BodyVelocity, Duration or 0.2)
					end
				end
			end
		end
		return true
	end,
}
