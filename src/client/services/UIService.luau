const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const LocalPlayer = Players.LocalPlayer

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Configuration = LocalPlayer.PlayerScripts.client.Configuration

const UIStartPoint = Configuration.UIStartPoint.Value

const UIService = Crane:CreateService({
	Name = "UIService",
})

function UIService:onStart()
	const PlayerService = Crane:GetService("PlayerService")

	if UIStartPoint and UIStartPoint:IsA("ModuleScript") then
		require(UIStartPoint)(PlayerService.Proxy, PlayerService.GameProxy)
	end
end

return UIService
