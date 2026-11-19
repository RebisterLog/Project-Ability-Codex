const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Knockback = require(ReplicatedStorage.shared.combat.Knockback)
const types = require(ServerScriptService.server.types)

--- Резолвер живёт в `shared/combat/Knockback.luau` и работает с плоскими
--- `{ x, y, z }`, чтобы его можно было тестировать вне Roblox. Граница с
--- Roblox-типами — только эта функция.
const function toVec(value: Vector3?): Knockback.Vec3?
	if not value then return nil end
	return { x = value.X, y = value.Y, z = value.Z }
end

return {
	Name = "Knockback",
	Type = "Cast",
	Priority = 90,
	Function = function(Data: types.AttackData)
		const State = Data.State
		const Info = Data.Info

		if State.Success and Info.Knockback then
			const AttackerPart = Data.Attacker.RootPart
			const TargetPart = Data.Victim.RootPart

			-- Без цели некуда прикреплять mover, поэтому дальше даже не идём.
			if TargetPart then
				const Result = Knockback.Build(Info.Knockback, {
					Attacker = toVec(AttackerPart and AttackerPart.Position),
					Target = toVec(TargetPart.Position),
					AttackerLook = toVec(AttackerPart and AttackerPart.CFrame.LookVector),
				})

				const Velocity =
					Vector3.new(Result.Velocity.x, Result.Velocity.y, Result.Velocity.z)
				const MaxForce =
					Vector3.new(Result.MaxForce.x, Result.MaxForce.y, Result.MaxForce.z)
				const Duration = Result.Hold
				const Stiffness = Result.Stiffness

				const targetPlayer = Players:GetPlayerFromCharacter(Data.Victim.instance)
				const attackerPlayer = Players:GetPlayerFromCharacter(Data.Attacker.instance)

				if targetPlayer then
					Crane:GetService("VFXService"):StartEffect({ targetPlayer }, "Knockback", {
						Part = TargetPart,
						Velocity = Velocity,
						MaxForce = MaxForce,
						Duration = Duration,
						Stiffness = Stiffness,
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
								Stiffness = Stiffness,
							})
					else
						const BodyVelocity = Instance.new("BodyVelocity")
						BodyVelocity.P = Stiffness
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
