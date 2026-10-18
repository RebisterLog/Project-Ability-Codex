const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Crane = require(ReplicatedStorage.shared.packages.Crane)

return {
	onStart = function(self, character: Model)
		const component = Crane:GetComponent("HeadInfo", character)
		if not component then return end

		(component :: any):SetStunned(true)
	end,

	onStop = function(self, character: Model)
		const component = Crane:GetComponent("HeadInfo", character)
		if not component then return end

		(component :: any):SetStunned(false)
	end,
}
