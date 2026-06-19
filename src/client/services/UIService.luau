local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Configuration = LocalPlayer.PlayerScripts.client.Configuration

local UIStartPoint = Configuration.UIStartPoint.Value

local UIService = Crane:CreateService({
	Name = "UIService"
})

function UIService:onStart()
	local PlayerService = Crane:GetService("PlayerService")
	
	if UIStartPoint and UIStartPoint:IsA("ModuleScript") then
		require(UIStartPoint)(PlayerService.Proxy, PlayerService.GameProxy)
	end
end

return UIService
