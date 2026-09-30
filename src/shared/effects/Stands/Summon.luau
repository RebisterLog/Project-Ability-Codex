local Crane = require(game:GetService("ReplicatedStorage").shared.packages.Crane)
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local StandsTweens = {}

local STYLE_IN = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local STYLE_OUT = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

return {
	Validate = function()
		return true
	end,

	onStart = function(self, stand: Model, state: boolean)
		if StandsTweens[stand] then return end

		if not stand then return end

		local parts = stand:QueryDescendants("BasePart") :: { BasePart }
		local decals = stand:QueryDescendants("Decal") :: { Decal }

		StandsTweens[stand] = {}

		for i, part in parts do
			local tween = TweenService:Create(part, state and STYLE_IN or STYLE_OUT, {
				Transparency = state and (part:GetAttribute("Transparency") or 0) or 1,
			})

			table.insert(StandsTweens[stand], tween)
			tween:Play()
		end

		for i, decal in decals do
			local tween = TweenService:Create(decal, state and STYLE_IN or STYLE_OUT, {
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
