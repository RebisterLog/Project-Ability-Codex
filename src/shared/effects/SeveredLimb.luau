type Cached = {
	Clone: Instance,
	Restore: () -> (),
}

const Cache: { [string]: Cached } = {}

-- Enums.Limb values are compact; the rigs are R6 with spaced part names.
const RIG_PARTS = {
	Head = "Head",
	Torso = "Torso",
	LeftArm = "Left Arm",
	RightArm = "Right Arm",
	LeftLeg = "Left Leg",
	RightLeg = "Right Leg",
} :: { [string]: string }

type SeverData = {
	Character: Model?,
	Limb: string?,
	Model: Instance?,
	Origin: CFrame?,
	UUID: string?,
}

const function noop() end

const function stripJoints(instance: Instance)
	for _, obj in instance:GetDescendants() do
		if obj:IsA("Motor6D") or obj:IsA("WeldConstraint") or obj:IsA("JointInstance") then
			obj:Destroy()
		end
	end
end

return {
	onStart = function(_, data: SeverData)
		const uuid = data.UUID
		if not uuid or Cache[uuid] then return end

		const character = data.Character
		const partName = data.Limb and (RIG_PARTS[data.Limb] or data.Limb) or ""
		const original = character and character:FindFirstChild(partName)

		local clone: Instance? = nil
		local restore: () -> () = noop

		if original and original:IsA("BasePart") then
			-- Only the limb itself, with its own decals/trails as children.
			-- Never clone sibling rig parts: a shared shoulder Motor6D would
			-- otherwise pull the whole torso along for the ride.
			const limb = original:Clone()
			stripJoints(limb)
			limb:PivotTo(data.Origin or original.CFrame)
			clone = limb

			const hidden: { { Part: BasePart, Transparency: number } } = {}
			const function hide(part: Instance)
				if not part:IsA("BasePart") then return end
				table.insert(hidden, { Part = part, Transparency = part.Transparency })
				part.Transparency = 1
			end
			hide(original)
			for _, obj in original:GetDescendants() do
				hide(obj)
			end

			restore = function()
				for _, entry in hidden do
					if entry.Part.Parent then entry.Part.Transparency = entry.Transparency end
				end
			end
		elseif data.Model then
			-- Fallback for rigs without the expected part: the global limb model.
			const template = data.Model:Clone()
			if template:IsA("Model") or template:IsA("BasePart") then
				stripJoints(template)
				template:PivotTo(
					data.Origin or (data.Character and data.Character:GetPivot()) or CFrame.identity
				)
				clone = template
			end
		end

		if not clone then return end

		for _, part in clone:QueryDescendants("BasePart") do
			part.Anchored = false
			part.CanCollide = true
			part:ApplyImpulse(
				Vector3.new(math.random(-3, 3), 8, math.random(-3, 3)) * part.AssemblyMass
			)
		end

		clone.Parent = workspace.Effects
		Cache[uuid] = { Clone = clone, Restore = restore }
	end,

	onStop = function(_, data: { UUID: string? })
		const uuid = data.UUID
		const entry = uuid and Cache[uuid]
		if not entry then return end
		entry.Restore()
		entry.Clone:Destroy()
		Cache[uuid] = nil
	end,
}
