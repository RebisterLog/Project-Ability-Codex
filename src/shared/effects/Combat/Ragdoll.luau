const RagdolledCharacters = {}

type RagdollData = {
	Character: Model?,
}

const Ragdoll = {
	onStart = function(self, data: RagdollData)
		const character = data.Character
		if character == nil then return end
		if table.find(RagdolledCharacters, character) then return end

		const humanoid: Humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		table.insert(RagdolledCharacters, character)
	end,

	onStop = function(self, data: RagdollData)
		const character = data.Character
		if character == nil then return end
		if not table.find(RagdolledCharacters, character) then return end
		table.remove(RagdolledCharacters, table.find(RagdolledCharacters, character))

		const humanoid: Humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end,
}

return Ragdoll
