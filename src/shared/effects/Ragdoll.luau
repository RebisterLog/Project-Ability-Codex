local RagdolledCharacters = {}

local Ragdoll = {
	onStart = function(self, character: Model)
		if table.find(RagdolledCharacters, character) then return end
		
		local humanoid: Humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end
		
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		table.insert(RagdolledCharacters, character)
	end,
	
	onStop = function(self, character: Model)
		if not table.find(RagdolledCharacters, character) then return end
		table.remove(RagdolledCharacters, table.find(RagdolledCharacters, character))

		local humanoid: Humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end,
}

return Ragdoll
