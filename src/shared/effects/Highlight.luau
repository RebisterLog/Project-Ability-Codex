local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

type HighlightData = {
	FillColor: Color3?,
	OutlineColor: Color3?,
	FillTransparency: number?,
	OutlineTransparency: number?,
	Lifetime: number,
	Tween: boolean?,
	Adornee: Instance?,
	UUID: string?,
}

local Cache = {}

return {
	Validate = function(self, character: Model)
		if
			(character:GetPivot().Position - workspace.CurrentCamera.CFrame.Position).Magnitude
			> 150
		then
			return false
		end
		return true
	end,

	onStart = function(self, Character: Model, Data: HighlightData)
		local Lifetime = Data.Lifetime

		local Highlight = Instance.new("Highlight")
		Highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		Highlight.FillColor = Data.FillColor or Color3.fromRGB(255, 0, 0)
		Highlight.OutlineColor = Data.OutlineColor or Color3.fromRGB(255, 255, 255)
		Highlight.FillTransparency = Data.FillTransparency or 0.5
		Highlight.OutlineTransparency = Data.OutlineTransparency or 0
		Highlight.Parent = Character

		if Data.Adornee then
			Highlight.Parent = workspace.Effects
			Highlight.Adornee = Data.Adornee
		end

		if Lifetime then
			task.delay(Lifetime + 0.25, Highlight.Destroy, Highlight)

			if Data.Tween then
				TweenService:Create(Highlight, TweenInfo.new(Lifetime), {
					OutlineTransparency = 1,
					FillTransparency = 1,
				}):Play()
			end
		elseif Data.UUID then
			Cache[Data.UUID] = Highlight
			Highlight.Destroying:Once(function()
				Cache[Data.UUID] = nil
			end)
		end
	end,
	onStop = function(self, UUID: number)
		local Highlight = Cache[UUID]
		if Highlight then Highlight:Destroy() end
	end,
}
