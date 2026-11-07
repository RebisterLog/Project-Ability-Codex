const Crane = require(game:GetService("ReplicatedStorage").shared.packages.Crane)
const RunService = game:GetService("RunService")
const TweenService = game:GetService("TweenService")

const StandsTweens = {}

const STYLE_IN = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
const STYLE_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

type SummonData = {
	Stand: Model?,
	-- True fades the rig in, false fades it out; the server sends the visibility
	-- it just applied to the stand.
	Visible: boolean?,
}

-- A fresh request replaces the tweens of the one already running, and the delayed
-- cleanup of an older transition must not cancel the tweens its replacement owns.
local function cancelTweens(stand: Model)
	const tweens = StandsTweens[stand]
	if tweens == nil then return end

	for _, tween in tweens :: { Tween } do
		tween:Cancel()
		tween:Destroy()
	end

	StandsTweens[stand] = nil
end

return {
	Validate = function()
		return true
	end,

	onStart = function(self, data: SummonData)
		local stand, visible = data.Stand, data.Visible
		if not stand then return end

		-- A visibility request supersedes the tween that was already in flight.
		-- Ignoring the request here leaves the visuals at the previous target when
		-- summon/unsummon are toggled faster than the tween duration.
		cancelTweens(stand)

		const parts = stand:QueryDescendants("BasePart") :: { BasePart }
		const decals = stand:QueryDescendants("Decal") :: { Decal }

		const tweens = {}
		StandsTweens[stand] = tweens

		for i, part in parts do
			const tween = TweenService:Create(part, visible and STYLE_IN or STYLE_OUT, {
				Transparency = visible and (part:GetAttribute("Transparency") or 0) or 1,
			})

			table.insert(tweens, tween)
			tween:Play()
		end

		for i, decal in decals do
			const tween = TweenService:Create(decal, visible and STYLE_IN or STYLE_OUT, {
				Transparency = visible and (decal:GetAttribute("Transparency") or 0) or 1,
			})

			table.insert(tweens, tween)
			tween:Play()
		end

		task.delay(visible and 1 or 0.5, function()
			-- A newer transition may now own this stand. Its tweens must not be
			-- cancelled by the delayed cleanup from an older transition.
			if StandsTweens[stand] == tweens then cancelTweens(stand) end
		end)
	end,

	onStop = function(self, data: SummonData)
		if data.Stand ~= nil then cancelTweens(data.Stand) end
	end,
}
