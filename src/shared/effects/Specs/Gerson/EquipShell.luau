local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Crane = require(ReplicatedStorage.shared.packages.Crane)

local Cleaners = {}

return {
	onStart = function(self, character: Model, shell: Model)
		if Cleaners[character] then return end

		local cleaner = Crane.Buttler.new()

		local copy = cleaner:Clone(shell) :: Model
		local weld = cleaner:Construct(Instance, "Weld") :: Weld
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

	onStop = function(self, character: Model)
		if Cleaners[character] then
			Cleaners[character]:Destroy()
			Cleaners[character] = nil
		end
	end,
}
