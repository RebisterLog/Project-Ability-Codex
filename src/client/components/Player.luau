const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Crane = require(ReplicatedStorage.shared.packages.Crane)

const Player: Crane.Component<Player> = Crane:CreateComponent({
	Name = "Player",
})

function Player.onStart(self: typeof(Player))
	self.instance.CharacterAdded:Connect(function(character)
		if self.Character then self.Character:Destroy() end

		self.Character = Crane:AddComponent(character, "Character")
	end)

	if self.instance.Character then
		self.Character = Crane:AddComponent(self.instance.Character, "Character")
	end
end

return Player
