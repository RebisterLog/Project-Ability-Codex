type KnockbackData = {
	Part: BasePart,
	Velocity: Vector3,
	MaxForce: Vector3?,
	Duration: number?,
	P: number?,
}

return {
	onStart = function(self, data: KnockbackData)
		local BodyVelocity = Instance.new("BodyVelocity")
		if data.P then BodyVelocity.P = data.P end
		BodyVelocity.Velocity = data.Velocity
		BodyVelocity.MaxForce = data.MaxForce or Vector3.new(100_000, 100_000, 100_000)

		BodyVelocity.Name = "KnockbackVelocity"
		BodyVelocity.Parent = data.Part

		game.Debris:AddItem(BodyVelocity, data.Duration or 0.2)
	end,

	onStop = function(self) end,
}
