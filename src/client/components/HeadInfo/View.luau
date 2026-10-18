const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const LocalPlayer = Players.LocalPlayer

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Fusion = require(ReplicatedStorage.shared.packages.Fusion)

const Children = Fusion.Children

export type Handle = {
	Stunned: Fusion.Value<boolean>,
	Destroy: () -> (),
}

return function(character: Model): Handle
	const scope = Fusion.scoped(Fusion)
	const cleaner = Crane.Buttler.new()

	const humanoid = character:WaitForChild("Humanoid") :: Humanoid
	const head = character:WaitForChild("Head") :: BasePart

	const player = Players:GetPlayerFromCharacter(character)
	--- Above own head the bar and the nickname only get in the way of the camera,
	--- so the local player sees just the stun label.
	const isLocal = character == LocalPlayer.Character

	const Health = scope:Value(1)
	const Stunned = scope:Value(false)

	const UpdateHealth = function()
		const ratio = humanoid.Health / math.max(humanoid.MaxHealth, 1)
		Health:set(math.clamp(ratio, 0, 1))
	end

	UpdateHealth()
	cleaner:Connect(humanoid.HealthChanged, UpdateHealth)
	cleaner:Connect(humanoid:GetPropertyChangedSignal("MaxHealth"), UpdateHealth)

	scope:New("BillboardGui")({
		Name = "HeadInfo",
		Active = true,
		AlwaysOnTop = true,
		MaxDistance = 50,
		Parent = head,
		Size = UDim2.fromScale(4, 2),
		StudsOffset = Vector3.new(0, 2, 0),
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,

		[Children] = {
			scope:New("Frame")({
				Name = "Main",
				Active = true,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),

				[Children] = {
					scope:New("CanvasGroup")({
						Name = "Health",
						AnchorPoint = Vector2.new(0, 1),
						BackgroundColor3 = Color3.fromRGB(0, 65, 35),
						BorderColor3 = Color3.new(),
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0, 1),
						Size = UDim2.fromScale(1, 0.15),
						Visible = not isLocal,
						ZIndex = 5,

						[Children] = {
							scope:New("Frame")({
								Name = "Bar",
								BackgroundColor3 = Color3.fromRGB(0, 255, 136),
								BorderColor3 = Color3.new(),
								BorderSizePixel = 0,
								Size = scope:Spring(
									scope:Computed(function(use)
										return UDim2.fromScale(use(Health), 1)
									end),
									25
								),
							}),

							scope:New("UIStroke")({
								Color = Color3.fromRGB(0, 120, 54),
								Thickness = 2,
							}),
						},
					}),

					scope:New("TextLabel")({
						Name = "Nickname",
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/Balthazar.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Normal
						),
						Position = UDim2.fromScale(0, 0.6),
						RichText = true,
						Size = UDim2.fromScale(1, 0.25),
						Text = player and player.DisplayName or character.Name,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextStrokeTransparency = 5,
						Visible = not isLocal,

						[Children] = {
							scope:New("UIStroke")({
								Thickness = 2,
							}),
						},
					}),

					scope:New("TextLabel")({
						Name = "Stunned",
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxassetid://11702779409",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Normal
						),
						Position = UDim2.fromScale(0, 0.2),
						RichText = true,
						Size = UDim2.fromScale(1, 0.5),
						Text = "STUNNED",
						TextColor3 = Color3.fromRGB(255, 35, 39),
						TextScaled = true,
						TextStrokeTransparency = 5,
						Visible = Stunned,

						[Children] = {
							scope:New("UIStroke")({
								Thickness = 2,
							}),
						},
					}),
				},
			}),
		},
	})

	return {
		Stunned = Stunned,

		Destroy = function()
			cleaner:Destroy()
			scope:doCleanup()
		end,
	}
end
