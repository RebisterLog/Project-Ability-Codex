local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local enums = require(ServerScriptService.server.Enums)
local types = require(ServerScriptService.server.types)

local CombatService = Crane:GetService("CombatService")

return {
	Name = "Angular",
	Type = "Cast",
	Priority = 90,
	Function = function(Data: types.AttackData)
		local State = Data.State
		local Info = Data.Info

		local targetPlayer = Players:GetPlayerFromCharacter(Data.Victim.instance)
		local attackerPlayer = Players:GetPlayerFromCharacter(Data.Attacker.instance)

		if State.Success then
			if State.Halt then return true end

			if Info.Angular then
				local TargetPart = Data.Victim.RootPart
				local RootAttachment = TargetPart:FindFirstChildOfClass("Attachment")

				local Duration = Info.Angular.Duration or 0.1
				local Speed = Info.Angular.Speed or 1

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
						AngularVelocity.MaxTorque = Info.Angular.MaxTorque or 100_0000

						game.Debris:AddItem(AngularVelocity, Duration)
					end
				end
			end
		end
		return true
	end,
}
