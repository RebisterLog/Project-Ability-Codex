type KnockbackData = {
	Part: BasePart?,
	Velocity: Vector3?,
	MaxForce: Vector3?,
	Duration: number?,
	P: number?,
	ClearMovers: boolean?,
}

const CollectionService = game:GetService("CollectionService")

return {
	onStart = function(self, data: KnockbackData)
		if not (data.Part and data.Velocity) then return end

		if data.ClearMovers then
			for _, mover in data.Part:GetChildren() do
				if mover:IsA("BodyMover") and not CollectionService:HasTag(mover, "NoRemove") then
					mover:Destroy()
				end
			end
		end

		const BodyVelocity = Instance.new("BodyVelocity")
		BodyVelocity.P = data.P or math.huge
		BodyVelocity.Velocity = data.Velocity
		BodyVelocity.MaxForce = data.MaxForce or Vector3.new(100_000, 100_000, 100_000)

		BodyVelocity.Name = "KnockbackVelocity"
		BodyVelocity.Parent = data.Part

		game.Debris:AddItem(BodyVelocity, data.Duration or 0.2)
	end,

	onStop = function(self, _data: KnockbackData) end,
}
