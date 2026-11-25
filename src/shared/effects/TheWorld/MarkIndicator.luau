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
		if not uuid or Cache[uuid] then return end

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
