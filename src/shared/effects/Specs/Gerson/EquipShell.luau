const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Crane = require(ReplicatedStorage.shared.packages.Crane)

const Cleaners = {}

return {
	Validate = function(self, data)
		return data and data.Character and data.Shell
	end,

	onStart = function(self, data)
		local character = data.Character
		local shell = data.Shell
		if Cleaners[character] then return end

		const cleaner = Crane.Buttler.new()

		const copy = cleaner:Clone(shell) :: Model
		const weld = cleaner:Construct(Instance, "Weld") :: Weld
		weld.Part0 = character:FindFirstChild("Left Arm")
		weld.Part1 = copy.PrimaryPart
		weld.C0 = CFrame.new(0, -2, -0.5) * CFrame.Angles(-90, 0, 0)
		weld.Parent = copy.PrimaryPart

		for i, v in copy:QueryDescendants("BasePart") do
			v.CanCollide = false
		end

		copy:ScaleTo(0.66)
		copy.Parent = workspace.Effects

		Cleaners[character] = cleaner

		task.delay(0.5, function()
			cleaner:Destroy()
			Cleaners[character] = nil
		end)
	end,

	onStop = function(self, data)
		local character = data and data.Character or data
		if character and Cleaners[character] then
			Cleaners[character]:Destroy()
			Cleaners[character] = nil
		end
	end,
}
