const Debris = game:GetService("Debris")

const Cache: { [string]: Instance } = {}

type SeverData = {
	Character: Model?,
	Limb: string?,
	Model: Instance?,
	Position: Vector3?,
	UUID: string?,
}

return {
	onStart = function(_, data: SeverData)
		const template = data.Model
		if not template then return end

		const clone = template:Clone()
		if not clone:IsA("Model") and not clone:IsA("BasePart") then return end

		for _, obj in clone:GetDescendants() do
			if obj:IsA("Motor6D") or obj:IsA("WeldConstraint") or obj:IsA("JointInstance") then
				obj:Destroy()
			end
		end

		const pivot = data.Position or (data.Character and data.Character:GetPivot().Position)
		if pivot then clone:PivotTo(CFrame.new(pivot + Vector3.new(0, 1, 0))) end

		for _, part in clone:QueryDescendants("BasePart") do
			part.Anchored = false
			part.CanCollide = true
			part:ApplyImpulse(
				Vector3.new(math.random(-3, 3), 8, math.random(-3, 3)) * part.AssemblyMass
			)
		end

		clone.Parent = workspace.Effects
		Debris:AddItem(clone, 5)
		if data.UUID then Cache[data.UUID] = clone end
	end,

	onStop = function(_, data: { UUID: string? })
		const uuid = data.UUID
		const clone = uuid and Cache[uuid]
		if clone then
			clone:Destroy()
			Cache[uuid] = nil
		end
	end,
}
