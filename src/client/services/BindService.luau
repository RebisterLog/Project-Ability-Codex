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

	const function rebuildBinds()
		table.clear(self.Binds)
		for _, slotSkills in self.playerProxy().Skills do
			for skillId, data in slotSkills do
				self.Binds[data.Parameters.Bind] = skillId
			end
		end
	end

	self.playerProxy:Subscribe("AnyChange", { "Skills" }, rebuildBinds)

	rebuildBinds()

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if JoystickBinds[input.KeyCode] then input = JoystickBinds[input.KeyCode] end

		const skillName = self.Binds[input]
			or self.Binds[input.KeyCode]
			or self.Binds[input.UserInputType]
		if not skillName then return end

		Crane:GetService("ClientSkillService"):Activate(skillName)
		Crane:GetPacket("StartSkill").send(skillName)
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if JoystickBinds[input.KeyCode] then input = JoystickBinds[input.KeyCode] end

		const skillName = self.Binds[input]
			or self.Binds[input.KeyCode]
			or self.Binds[input.UserInputType]
		if not skillName then return end

		Crane:GetService("ClientSkillService"):Stop(skillName)
		Crane:GetPacket("StopSkill").send(skillName)
	end)
end

return BindService
