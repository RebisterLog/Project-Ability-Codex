local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Crane = require(ReplicatedStorage.shared.packages.Crane)

local Character = Crane:CreateComponent({
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