local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
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

				local Velocity = (Info.Knockback.Velocity or Vector3.zero)
					+ ((LookVector or Vector3.zero) * Speed)

				local MaxForce = Info.Knockback.MaxForce
				if not MaxForce then
					if math.abs(Velocity.Y) < 1e-3 then
						MaxForce = Vector3.new(100_000, 0, 100_000)
					else
						MaxForce = Vector3.new(100_000, 100_000, 100_000)
					end
				end

				local P = Info.Knockback.P

				if targetPlayer then
					Crane:GetService("VFXService"):StartEffect({ targetPlayer }, "Knockback", {
						Part = TargetPart,
						Velocity = Velocity,
						MaxForce = MaxForce,
						Duration = Duration,
						P = P,
					})
				else
					Crane.Utils.ChangeNetworkOwner(Data.Victim.instance, attackerPlayer)

					if attackerPlayer then
						Crane:GetService("VFXService")
							:StartEffect({ attackerPlayer }, "Knockback", {
								Part = TargetPart,
								Velocity = Velocity,
								MaxForce = MaxForce,
								Duration = Duration,
								P = P,
							})
					else
						local BodyVelocity = Instance.new("BodyVelocity")
						if P then BodyVelocity.P = P end
						BodyVelocity.Velocity = Velocity
						BodyVelocity.MaxForce = MaxForce

						BodyVelocity.Name = "KnockbackVelocity"
						BodyVelocity.Parent = TargetPart

						game.Debris:AddItem(BodyVelocity, Duration)
					end
				end
			end
		end
		return true
	end,
}
