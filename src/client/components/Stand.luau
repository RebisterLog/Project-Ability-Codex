const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const SharedStand = require(ReplicatedStorage.shared.components.Stand)
const LocalPlayer = Players.LocalPlayer

const Crane = require(ReplicatedStorage.shared.packages.Crane)

const Stand = Crane:CreateComponent({
	Name = "Stand",
	Tag = "Stand",
	BaseComponent = SharedStand,
})

function Stand:onStart()
	self.Cleaner = Crane.Buttler.new()
	self.RootPart = self.instance:FindFirstChild("HumanoidRootPart") or self.instance.PrimartPart

	self:HandleMovement()
end

function Stand:Destroy() end

return Stand
