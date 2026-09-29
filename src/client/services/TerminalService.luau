local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crane = require(ReplicatedStorage.shared.packages.Crane)

local TerminalService = Crane:CreateService({
	Name = "TerminalService",
})

function TerminalService:onStart()
	local CmdrClient = ReplicatedStorage:WaitForChild("CmdrClient")
	require(CmdrClient)
end

return TerminalService