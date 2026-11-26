const Signs: { [number]: Model } = {}

type SignData = {
	UUID: number,
	Model: Model?,
	Origin: CFrame?,
	Duration: number?,
}

return {
	onStart = function(_, data: SignData)
		const uuid = data.UUID
		if Signs[uuid] then return end
		const template = data.Model
		if not template then return end

		const sign = template:Clone()

		-- A static ground prop: no Roblox physics, no collision, no ray queries.
		-- It stays exactly where PivotTo puts it until the cast ends.
		const parts = if sign:IsA("BasePart")
			then { sign }
			else sign:QueryDescendants("BasePart") :: { BasePart }
		for _, part in parts do
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end

		sign:PivotTo(
			(data.Origin or CFrame.identity)
				* CFrame.new(0, 0, -3)
				* CFrame.Angles(0, 0, math.pi / 2)
		)
		sign.Parent = workspace:FindFirstChild("Effects") or workspace
		Signs[uuid] = sign

		if data.Duration then
			task.delay(data.Duration, function()
				if Signs[uuid] == sign then
					sign:Destroy()
					Signs[uuid] = nil
				end
			end)
		end
	end,

	onStop = function(_, data: { UUID: number })
		const sign = data.UUID and Signs[data.UUID]
		if sign then
			sign:Destroy()
			Signs[data.UUID] = nil
		end
	end,
}
