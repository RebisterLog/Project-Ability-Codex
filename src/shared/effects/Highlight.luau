const ReplicatedStorage = game:GetService("ReplicatedStorage")
const TweenService = game:GetService("TweenService")

type HighlightData = {
	Character: Model?,
	UUID: string?,
	FillColor: Color3?,
	OutlineColor: Color3?,
	FillTransparency: number?,
	OutlineTransparency: number?,
	Lifetime: number?,
	Tween: boolean?,
	Adornee: Instance?,
}

type HighlightStopData = {
	UUID: string?,
}

const Cache = {}

return {
	Validate = function(self, data: HighlightData)
		const character = data.Character
		if character == nil then return true end

		if
			(character:GetPivot().Position - workspace.CurrentCamera.CFrame.Position).Magnitude
			> 150
		then
			return false
		end
		return true
	end,

	onStart = function(self, data: HighlightData)
		const Lifetime = data.Lifetime

		const Highlight = Instance.new("Highlight")
		Highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		Highlight.FillColor = data.FillColor or Color3.fromRGB(255, 0, 0)
		Highlight.OutlineColor = data.OutlineColor or Color3.fromRGB(255, 255, 255)
		Highlight.FillTransparency = data.FillTransparency or 0.5
		Highlight.OutlineTransparency = data.OutlineTransparency or 0

		if data.Adornee then
			Highlight.Parent = workspace.Effects
			Highlight.Adornee = data.Adornee
		else
			Highlight.Parent = data.Character
		end

		if Lifetime then
			task.delay(Lifetime + 0.25, Highlight.Destroy, Highlight)

			if data.Tween then
				TweenService:Create(Highlight, TweenInfo.new(Lifetime), {
					OutlineTransparency = 1,
					FillTransparency = 1,
				}):Play()
			end
		elseif data.UUID then
			Cache[data.UUID] = Highlight
			Highlight.Destroying:Once(function()
				Cache[data.UUID] = nil
			end)
		end
	end,
	onStop = function(self, data: HighlightStopData)
		const Highlight = Cache[data.UUID]
		if Highlight then Highlight:Destroy() end
	end,
}
