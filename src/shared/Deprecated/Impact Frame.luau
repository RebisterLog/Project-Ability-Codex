const ReplicatedStorage = game:GetService("ReplicatedStorage")
const CacheTab = require(ReplicatedStorage.shared.packages.CacheTab)

const ImpactFrame = {
	CachedHighlights = CacheTab.new(script.Highlight, 10, function(highlight: Highlight)
		highlight.Adornee = nil
		highlight.Parent = nil
	end, function(highlight: Highlight) end),
	CachedColorCorrection = CacheTab.new(
		script.ColorCorrection,
		10,
		function(colorCor: ColorCorrectionEffect)
			colorCor.Parent = nil
		end,
		function(colorCor: ColorCorrectionEffect) end
	),
}

function ImpactFrame.onStart(self: typeof(ImpactFrame), models: { Model }, time: number?)
	time = time or 0.1

	task.spawn(function()
		const colorCor = self.CachedColorCorrection:Get()
		colorCor.Parent = game.Lighting
		task.wait(time / 2)
		colorCor.Brightness = -1
		task.wait(time / 2)
		self.CachedColorCorrection:Add(colorCor)
	end)

	for _, model in models do
		task.spawn(function()
			const highlight = self.CachedHighlights:Get()
			highlight.FillColor = Color3.fromRGB(0, 0, 0)
			highlight.FillTransparency = 0
			highlight.OutlineTransparency = 1
			highlight.Adornee = model
			highlight.Parent = workspace.Effects
			task.wait(time / 2)
			highlight.FillColor = Color3.new(1, 1, 1)
			task.wait(time / 2)
			self.CachedHighlights:Add(highlight)
		end)
	end
end

return ImpactFrame
