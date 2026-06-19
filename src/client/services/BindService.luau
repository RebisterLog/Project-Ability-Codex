local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Proxy = require(ReplicatedStorage.shared.packages.Proxy)
local PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)

local JoystickBinds = require(script.Parent.Parent.controls.JoystickBinds)

local BindService = Crane:CreateService({
	Name = "BindService",
})
BindService.Binds = {}

function BindService.onStart(self: typeof(BindService))
	self.playerProxy = Crane:GetService("PlayerService").Proxy :: Proxy.ProxyTab<PlayerData.PlayerData>
	
	self.playerProxy:Subscribe("AnyChange", {"Skills"}, function()
		for skillId, data in self.playerProxy().Skills do
			self.Binds[data.Parameters.Bind] = skillId
		end
	end)
	
	for skillId, data in self.playerProxy().Skills do
		self.Binds[data.Parameters.Bind] = skillId
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if JoystickBinds[input.KeyCode] then
			input = JoystickBinds[input.KeyCode]
		end

		local skillName = self.Binds[input] or self.Binds[input.KeyCode] or self.Binds[input.UserInputType]
		if not skillName then return end

		Crane:GetPacket("StartSkill").send(skillName)
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if JoystickBinds[input.KeyCode] then
			input = JoystickBinds[input.KeyCode]
		end

		local skillName = self.Binds[input] or self.Binds[input.KeyCode] or self.Binds[input.UserInputType]
		if not skillName then return end

		Crane:GetPacket("StopSkill").send(skillName)
	end)
end

return BindService
