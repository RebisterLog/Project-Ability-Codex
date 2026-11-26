const Players = game:GetService("Players")

const Cache: { [string]: Instance } = {}

type MarkData = {
	UUID: string?,
	Character: Model?,
	Count: number?,
}

return {
	onStart = function(_, data: MarkData)
		const uuid = data.UUID
		if not uuid then return end

		const existing = Cache[uuid]
		if existing then
			-- The same indicator is reused for 1/3, 2/3 and 3/3: keep the label in sync.
			const label = existing:FindFirstChild("TextLabel")
			if label and label:IsA("TextLabel") then
				label.Text = ("MARK %d/3"):format(math.clamp(data.Count or 0, 0, 3))
			end
			return
		end

		const character = data.Character
		const root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then return end

		const gui = Instance.new("BillboardGui")
		gui.Name = "MarkIndicator"
		gui.Adornee = root
		gui.AlwaysOnTop = true
		gui.Size = UDim2.fromOffset(120, 36)
		gui.StudsOffset = Vector3.new(0, 2.5, 0)

		const label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.Size = UDim2.fromScale(1, 1)
		label.Text = ("MARK %d/3"):format(math.clamp(data.Count or 0, 0, 3))
		label.TextColor3 = Color3.fromRGB(220, 120, 255)
		label.TextScaled = true
		label.Parent = gui

		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		Cache[uuid] = gui
	end,

	onStop = function(_, data: { UUID: string? })
		const uuid = data.UUID
		const gui = uuid and Cache[uuid]
		if gui then
			gui:Destroy()
			Cache[uuid] = nil
		end
	end,
}
