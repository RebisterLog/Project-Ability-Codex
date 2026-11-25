const Players = game:GetService("Players")
const Debris = game:GetService("Debris")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Cache: { [string]: Instance } = {}

type WarningData = {
	UUID: string?,
	Caster: Model?,
	Target: Model?,
	Stand: Model?,
	Duration: number?,
}

return {
	onStart = function(_, data: WarningData)
		const uuid = data.UUID
		if not uuid or Cache[uuid] then return end

		const holder = Instance.new("Folder")
		holder.Name = "DistantSlamWarning"
		holder.Parent = workspace.Effects

		const screen = Instance.new("ScreenGui")
		screen.Name = "DistantSlamWarning"
		screen.ResetOnSpawn = false
		screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

		const label = Instance.new("TextLabel")
		label.BackgroundTransparency = 0.4
		label.BackgroundColor3 = Color3.fromRGB(40, 0, 0)
		label.Font = Enum.Font.GothamBold
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.new(0.5, 0, 0.15, 0)
		label.Size = UDim2.fromOffset(420, 54)
		label.Text = "DISTANT SLAM INCOMING"
		label.TextColor3 = Color3.fromRGB(255, 130, 130)
		label.TextScaled = true
		label.Parent = screen

		const template =
			ReplicatedStorage.assets.TheWorld.None.Models:FindFirstChild("DistantSlamWarning")
		const standRoot = data.Stand and data.Stand:FindFirstChild("HumanoidRootPart") or data.Stand
		if template and standRoot and standRoot:IsA("BasePart") then
			const clone = template:Clone()
			if clone:IsA("BasePart") then
				const weld = Instance.new("Weld")
				weld.Part0 = standRoot
				weld.Part1 = clone
				weld.Parent = clone
				clone.Anchored = false
			end
			clone.Parent = holder
		end

		holder:SetAttribute("Duration", data.Duration or 1)
		Cache[uuid] = holder
		Debris:AddItem(screen, (data.Duration or 1) + 0.5)
	end,

	onStop = function(_, data: { UUID: string? })
		const uuid = data.UUID
		const holder = uuid and Cache[uuid]
		if holder then
			holder:Destroy()
			Cache[uuid] = nil
		end
	end,
}
