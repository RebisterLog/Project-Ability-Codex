--!native
--!optimize 2

local TweenService = game:GetService("TweenService")

local RNG = Random.new()

-- Floating damage number that accumulates total damage dealt to the same
-- character (per gradient/type) within a short window, instead of spawning a
-- new number for every hit.
local DamageIndicator = {
	Cache = {},
}

for _, Gradient in script:WaitForChild("Gradients"):GetChildren() do
	DamageIndicator.Cache[Gradient.Name] = {}
end

local function getBucket(gradientName: string)
	local bucket = DamageIndicator.Cache[gradientName]
	if not bucket then
		bucket = {}
		DamageIndicator.Cache[gradientName] = bucket
	end
	return bucket
end

type DamageIndicatorData = {
	Character: Model?,
	Amount: number?,
	-- Optional: selects a gradient from script.Gradients (defaults to "Damage").
	Type: string?,
	Gradient: string?,
}

function DamageIndicator:onStart(data: DamageIndicatorData)
	local character = data.Character
	local amount = data.Amount
	if character == nil or amount == nil or amount == 0 then return end
	if not character:IsDescendantOf(workspace) then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then return end

	local gradientName = data.Type or data.Gradient or "Damage"
	local bucket = getBucket(gradientName)

	local isFirst = false
	local indicatorData = bucket[character]

	if not indicatorData or not indicatorData.Indicator or not indicatorData.Indicator.Parent then
		isFirst = true

		local indicator = script.DamageIndicator:Clone()
		indicator.Name = ("%*Indicator"):format(gradientName)
		indicator.Enabled = true
		indicator.Adornee = workspace.Terrain
		indicator.Archivable = false

		local gradient = script.Gradients:FindFirstChild(gradientName)
		if gradient then
			gradient:Clone().Parent = indicator.Label
		end

		indicator.Parent = character

		indicatorData = {
			Indicator = indicator,
			Value = 0,
		}
		bucket[character] = indicatorData
	end

	indicatorData.Value += amount

	local label = indicatorData.Indicator:FindFirstChild("Label")
	if not label or not label:IsA("TextLabel") then return end

	label.Text = if indicatorData.Value % 1 > 0
		then string.format("%.2f", indicatorData.Value)
		else tostring(math.floor(indicatorData.Value))

	local offset = rootPart.Position
		+ Vector3.new(RNG:NextNumber(-1, 1), RNG:NextNumber(-1, 1), RNG:NextNumber(-1, 1))

	if isFirst then
		indicatorData.Indicator.StudsOffsetWorldSpace = offset
	else
		TweenService:Create(
			indicatorData.Indicator,
			TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ StudsOffsetWorldSpace = offset }
		):Play()
	end

	local oldValue = indicatorData.Value
	task.delay(1.5, function()
		-- Only clear if no new damage was added since this tick and the indicator
		-- still belongs to this character bucket.
		if bucket[character] ~= indicatorData then return end
		if indicatorData.Value ~= oldValue then return end

		if indicatorData.Indicator then
			indicatorData.Indicator:Destroy()
		end
		bucket[character] = nil
	end)
end

return DamageIndicator
