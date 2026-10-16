const ReplicatedStorage = game:GetService("ReplicatedStorage")
const TweenService = game:GetService("TweenService")
const AnimationActor = game.Players.LocalPlayer.PlayerScripts.client.Animations
const Skins = require(ReplicatedStorage.shared.configs.Skins)
const RNG = Random.new()

const DamageIndicator = {
	Cache = {},
}
for _, Gradient in script:WaitForChild("Gradients"):GetChildren() do
	DamageIndicator.Cache[Gradient.Name] = {}
end

function DamageIndicator:onStart(Character: Model, Amount: number, GradientName: string)
	if not (Character and Character:IsDescendantOf(workspace)) then return end
	const RootPart = Character:FindFirstChild("HumanoidRootPart")
	if not RootPart then return end

	const GradientName = GradientName or "Damage"

	local IsFirst = false
	local IndicatorData = self.Cache[GradientName][Character]

	if not IndicatorData then
		IsFirst = true

		const Indicator = script.DamageIndicator:Clone()
		Indicator.Name = ("%*Indicator"):format(GradientName)
		Indicator.Enabled = true
		Indicator.Adornee = workspace.Terrain
		Indicator.Archivable = false

		const Gradient = script.Gradients:FindFirstChild(GradientName)
		if Gradient then Gradient:Clone().Parent = Indicator.Label end

		Indicator.Parent = Character

		IndicatorData = {
			Indicator = Indicator,
			Value = 0,
		}
		self.Cache[GradientName][Character] = IndicatorData
	end

	IndicatorData.Value += Amount
	IndicatorData.Indicator.Label.Text = IndicatorData.Value % 1 > 0
			and string.format("%.2f", IndicatorData.Value)
		or math.floor(IndicatorData.Value)

	const Offset = RootPart.CFrame.Position
		+ Vector3.new(RNG:NextNumber(-1, 1), RNG:NextNumber(-1, 1), RNG:NextNumber(-1, 1))

	if IsFirst then
		IndicatorData.Indicator.StudsOffsetWorldSpace = Offset
	else
		TweenService:Create(
			IndicatorData.Indicator,
			TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{
				StudsOffsetWorldSpace = Offset,
			}
		):Play()
	end

	const oldValue = IndicatorData.Value
	task.delay(1.5, function()
		if IndicatorData.Value == oldValue then
			IndicatorData.Indicator:Destroy()
			self.Cache[GradientName][Character] = nil
		end
	end)
end

return DamageIndicator
