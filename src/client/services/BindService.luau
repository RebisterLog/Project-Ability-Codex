const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const UserInputService = game:GetService("UserInputService")

const LocalPlayer = Players.LocalPlayer
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)

const JoystickBinds = require(script.Parent.Parent.controls.JoystickBinds)

const BindService = Crane:CreateService({
	Name = "BindService",
})
BindService.Binds = {}

function BindService.onStart(self: typeof(BindService))
	self.playerProxy =
		Crane:GetService("PlayerService").Proxy :: Proxy.ProxyTab<PlayerData.PlayerData>

	self.playerProxy:Subscribe("AnyChange", { "Skills" }, function()
		for skillId, data in self.playerProxy().Skills do
			self.Binds[data.Parameters.Bind] = skillId
		end
	end)

	for skillId, data in self.playerProxy().Skills do
		self.Binds[data.Parameters.Bind] = skillId
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if JoystickBinds[input.KeyCode] then input = JoystickBinds[input.KeyCode] end

		const skillName = self.Binds[input]
			or self.Binds[input.KeyCode]
			or self.Binds[input.UserInputType]
		if not skillName then return end

		Crane:GetPacket("StartSkill").send(skillName)
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if JoystickBinds[input.KeyCode] then input = JoystickBinds[input.KeyCode] end

		const skillName = self.Binds[input]
			or self.Binds[input.KeyCode]
			or self.Binds[input.UserInputType]
		if not skillName then return end

		Crane:GetPacket("StopSkill").send(skillName)
	end)
end

return BindService
