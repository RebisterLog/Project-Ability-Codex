type AngularData = {
	Part: BasePart,
	Velocity: Vector3,
	Speed: number?,
	MaxTorque: number?,
	Duration: number?,
}

return {
	onStart = function(self, data: AngularData)
		local Attachment = Instance.new("Attachment")
		Attachment.Parent = data.Part

		local AngularVelocity = Instance.new("AngularVelocity")
		AngularVelocity.Attachment0 = Attachment
		AngularVelocity.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		AngularVelocity.AngularVelocity = data.Velocity * (data.Speed or 1)
		AngularVelocity.MaxTorque = data.MaxTorque or 100_0000

		AngularVelocity.Name = "AngularVelocity"
		AngularVelocity.Parent = data.Part

		game.Debris:AddItem(AngularVelocity, data.Duration or 0.2)
		game.Debris:AddItem(Attachment, data.Duration or 0.2)
	end,

	onStop = function(self) end,
}
