const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Crane = require(ReplicatedStorage.shared.packages.Crane)

type CharacterData = {
	Character: Model?,
}

return {
	onStart = function(self, data: CharacterData)
		const component = Crane:GetComponent("HeadInfo", data.Character)
		if not component then return end

		(component :: any):SetStunned(true)
	end,

	onStop = function(self, data: CharacterData)
		const component = Crane:GetComponent("HeadInfo", data.Character)
		if not component then return end

		(component :: any):SetStunned(false)
	end,
}
