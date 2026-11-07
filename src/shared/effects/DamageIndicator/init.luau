--!native
--!optimize 2

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const TweenService = game:GetService("TweenService")

const Sequencer = require(ReplicatedStorage.shared.packages.Sequencer)

--[=[
	Floating damage number over the victim, one clone per hit.

	Every number, easing and delay below is copied from the legacy
	`Modules.Effects.Combat.DamageIndicator`, and `DamageIndicator.rbxm` is the
	legacy `BillboardGui` transferred instance-for-instance — same 4x2 box, same
	bold-italic asset font, Bright red fill, grey->white gradient, 2.5 white
	stroke with its own dark-red gradient. Two things differ, because this project
	ports no parts:

	- the legacy transparent 1x1x1 part dropped into `workspace.Effects` became an
	  `Attachment` in the same folder, which the BillboardGui adorns. The number is
	  still anchored where the hit landed and does not follow the victim;
	- legacy read the R6 `Torso`, here the root is `HumanoidRootPart`.

	One deliberate adaptation: legacy measured the `±1.6 … 4.0` stud spread along
	the X axis of the *attacker's* frame (`TagHumanoid` passed its `LookVector`),
	which collapses every number into one screen column whenever the attacker
	faces along the camera. The same magnitude is applied here along the viewer's
	horizontal camera axis, resolved per client; the `0.6 … 2.7` stud height and
	the 5 stud rise stay world-up, as in legacy.

	Legacy read `Properties.Type` and never used it, so the gradient name stays
	unused here too — it is kept as the slot for future damage-type colors, which
	`Gradients/` already feeds.
]=]

-- Sequencer counts 60 frames per second: the legacy `task.delay(.5)` fade and
-- the `Debris:AddItem(Indicator, 1.5)` removal.
const FADE_FRAME = 30
const DEATH_FRAME = 90

const RISE = Vector3.new(0, 5, 0)
const RISE_TWEEN = TweenInfo.new(1.5, Enum.EasingStyle.Circular, Enum.EasingDirection.In)
const POP_TWEEN = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
const FADE_TWEEN = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-- Legacy ladder, read from the largest threshold down. The legacy source asked
-- `>= 5` first, which left `>= 10 … >= 50` unreachable; the ladder applies in
-- full here, as agreed.
local function textSize(Damage: number): number
	if Damage >= 50 then
		return 1
	elseif Damage >= 30 then
		return 0.9
	elseif Damage >= 20 then
		return 0.87
	elseif Damage >= 10 then
		return 0.75
	elseif Damage >= 5 then
		return 0.68
	end

	return 0.4
end

type DamageIndicatorData = {
	Character: Model?,
	Amount: number?,
}

return {
	onStart = function(self, data: DamageIndicatorData)
		local character, amount = data.Character, data.Amount
		if character == nil or amount == nil or amount == 0 then return end

		const root = character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then return end

		const Damage = math.floor(amount * 10 + 0.5) / 10

		const Indicator = script.DamageIndicator:Clone()
		const Label = Indicator.TextLabel

		Label.Text = "-" .. tostring(Damage)
		Label.Size = UDim2.fromScale(1, 0)

		-- The viewer's horizontal axis, so the fan reads as a fan from any angle.
		local spread = Vector3.new(
			workspace.CurrentCamera.CFrame.RightVector.X,
			0,
			workspace.CurrentCamera.CFrame.RightVector.Z
		)
		if spread.Magnitude < 0.001 then
			spread = Vector3.new(root.CFrame.RightVector.X, 0, root.CFrame.RightVector.Z)
		end

		local Offset = -1.5
		if math.random(1, 2) == 1 then
			Offset = -1.5 - math.random(1, 25) / 10
		else
			Offset = 1.5 + math.random(1, 25) / 10
		end

		-- The legacy part anchor: an attachment in `workspace.Effects` holds the
		-- world position the hit landed at, so the number never rides the victim.
		const Anchor = Instance.new("Attachment")
		Anchor.Name = "DamageIndicator"
		Anchor.Parent = workspace.Effects
		Anchor.WorldPosition = root.Position
			+ spread.Unit * Offset
			+ Vector3.new(0, 0.5 + math.random(1, 22) / 10, 0)

		const start = Anchor.WorldPosition

		Indicator.Adornee = Anchor
		Indicator.Parent = workspace.Effects
		TweenService:Create(Anchor, RISE_TWEEN, { WorldPosition = start + RISE }):Play()

		Label.Rotation = math.random(-90, 90)
		TweenService:Create(Label, POP_TWEEN, {
			Size = UDim2.fromScale(1, textSize(Damage)),
			Rotation = 0,
		}):Play()

		const sequence = Sequencer.new({
			Frames = {
				{
					FADE_FRAME,
					function()
						TweenService:Create(Label, FADE_TWEEN, { TextTransparency = 1 }):Play()

						const Stroke = Label:FindFirstChildOfClass("UIStroke")
						if Stroke ~= nil then
							TweenService:Create(Stroke, FADE_TWEEN, { Transparency = 1 }):Play()
						end
					end,
				},
				{ DEATH_FRAME },
			},
		})

		sequence.Cleaner:Add(Indicator)
		sequence.Cleaner:Add(Anchor)
		sequence:Play()
	end,
}
