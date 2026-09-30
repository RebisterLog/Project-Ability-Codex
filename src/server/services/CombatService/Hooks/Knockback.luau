local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local enums = require(ServerScriptService.server.Enums)
local types = require(ServerScriptService.server.types)

local CombatService = Crane:GetService("CombatService")

return {
	Name = "Knockback",
	Type = "Cast",
	Priority = 90,
	Function = function(Data: types.AttackData)
		local State = Data.State
		local Info = Data.Info

		if State.Success then
			if State.Halt then return true end

			if Info.Knockback then
				local AttackerPart = Data.Attacker.RootPart
				local TargetPart = Data.Victim.RootPart
				local LookVector = Info.Knockback.LookVector or Vector3.zero

				local targetPlayer = Players:GetPlayerFromCharacter(Data.Victim.instance)
				local attackerPlayer = Players:GetPlayerFromCharacter(Data.Attacker.instance)

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

				local Duration = Info.Knockback.Duration or 0.1
				local Speed = Info.Knockback.Speed or 1

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
						local BodyVelocity = Instance.new("BodyVelocity")
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
