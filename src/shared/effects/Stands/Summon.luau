const Crane = require(game:GetService("ReplicatedStorage").shared.packages.Crane)
const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")

const StandsTweens = {}

const STYLE_IN = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
const STYLE_OUT = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

return {
	Validate = function()
		return true
	end,

	onStart = function(self, stand: Model, state: boolean)
		if StandsTweens[stand] then return end

		if not stand then return end

		const parts = stand:QueryDescendants("BasePart") :: { BasePart }
		const decals = stand:QueryDescendants("Decal") :: { Decal }

		StandsTweens[stand] = {}

		for i, part in parts do
			const tween = TweenService:Create(part, state and STYLE_IN or STYLE_OUT, {
				Transparency = state and (part:GetAttribute("Transparency") or 0) or 1,
			})

			table.insert(StandsTweens[stand], tween)
			tween:Play()
		end

		for i, decal in decals do
			const tween = TweenService:Create(decal, state and STYLE_IN or STYLE_OUT, {
				Transparency = state and (decal:GetAttribute("Transparency") or 0) or 1,
			})

			table.insert(StandsTweens[stand], tween)
			tween:Play()
		end

		task.delay(state and 1 or 0.5, function()
			self:onStop(stand)
		end)
	end,

	onStop = function(self, stand: Model)
		if StandsTweens[stand] then
			for i, tween in StandsTweens[stand] :: { Tween } do
				tween:Cancel()
				tween:Destroy()
			end

			StandsTweens[stand] = nil
		end
	end,
}
