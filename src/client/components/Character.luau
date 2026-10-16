const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const LocalPlayer = Players.LocalPlayer

const Crane = require(ReplicatedStorage.shared.packages.Crane)

const Character = Crane:CreateComponent({
	Name = "Character",
})

function Character.onStart(self: typeof(Character))
	self.Humanoid = self.instance:WaitForChild("Humanoid") :: Humanoid
	self.Root = self.instance:WaitForChild("HumanoidRootPart") :: BasePart
	self.Cleaner = Crane.Buttler.new()
	self.Tricks = {}
end

function Character:Destroy()
	self.Cleaner:Clean()
end

return Character
