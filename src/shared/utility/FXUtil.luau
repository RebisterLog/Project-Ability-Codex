local module = {}

export type AttachConfig = {
	Part: BasePart,
	Offset: CFrame | Vector3 | BasePart | Attachment | Model?,
	UseMotor6D: boolean?,
	MakePartP0: boolean?,
	InverseAttach: boolean?,
	MakePartParent: boolean?,
	C0: CFrame?,
	C1: CFrame?,
	Duration: number?,
}

function module.TranslateToCFrame(origin: CFrame | Vector3 | Instance?): CFrame?
	local originType = typeof(origin)

	if originType == "CFrame" then
		return origin :: CFrame
	elseif originType == "Vector3" then
		return CFrame.new(origin :: Vector3)
	elseif originType == "Instance" then
		local instance = origin :: Instance

		if not instance:IsDescendantOf(game) then return nil end

		if instance:IsA("BasePart") then
			return instance.CFrame
		elseif instance:IsA("Attachment") then
			return instance.WorldCFrame
		elseif instance:IsA("Model") then
			local primaryPart = instance:FindFirstChild("Torso") or instance.PrimaryPart

			if primaryPart and primaryPart:IsA("BasePart") then return primaryPart.CFrame end

			for _, descendant in instance:GetDescendants() do
				if descendant:IsA("BasePart") then return instance:GetPivot() end
			end
		end
	end

	return nil
end

function module.MoveTo(inst: BasePart | Model, origin: CFrame?): ()
	if not origin then return end

	if inst:IsA("Model") then
		if not inst.PrimaryPart then
			warn(inst, "needs a PrimaryPart")
			return
		end

		inst:PivotTo(origin)
	else
		inst.CFrame = origin
	end
end

function module.AttachTo(inst: BasePart | Model, config: AttachConfig): Weld | Motor6D?
	if type(config) ~= "table" then return nil end

	local targetPart = config.Part

	if not targetPart or not targetPart:IsDescendantOf(workspace) then return nil end

	if inst:IsA("Model") and not inst.PrimaryPart then
		warn(inst, "needs a PrimaryPart")
		return nil
	end

	local offset = module.TranslateToCFrame(config.Offset)

	if inst:IsA("Model") then inst = inst.PrimaryPart :: BasePart end

	inst.Anchored = false
	inst.CanCollide = false
	inst.Massless = true

	local weld: Weld | Motor6D = Instance.new(config.UseMotor6D and "Motor6D" or "Weld")

	local inverseAttach = config.MakePartP0 or config.InverseAttach

	weld.Part0 = inverseAttach and targetPart or inst
	weld.Part1 = inverseAttach and inst or targetPart

	weld.Parent = config.MakePartParent and targetPart or inst

	if config.C0 then weld.C0 = config.C0 end

	if config.C1 then weld.C1 = config.C1 end

	if offset then weld.C0 = weld.C0 * offset end

	if config.Duration then task.delay(config.Duration, weld.Destroy, weld) end

	return weld
end

return module
