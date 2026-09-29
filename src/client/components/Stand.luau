local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedStand = require(ReplicatedStorage.shared.components.Stand)
local LocalPlayer = Players.LocalPlayer

local Crane = require(ReplicatedStorage.shared.packages.Crane)

local Stand = Crane:CreateComponent({
	Name = "Stand",
	Tag = "Stand",
	BaseComponent = SharedStand,
})

function Stand:onStart()
	self.Cleaner = Crane.Buttler.new()
	self.RootPart = self.instance:FindFirstChild("HumanoidRootPart") or self.instance.PrimartPart
	
	self:HandleMovement()
end

function Stand:Destroy()
	
end

return Stand