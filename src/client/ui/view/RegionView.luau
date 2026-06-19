local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalizationService = game:GetService("LocalizationService")

local Fusion = require(ReplicatedStorage.shared.packages.Fusion)
local OnEvent = require(ReplicatedStorage.shared.packages.Fusion.Instances.OnEvent)
local peek = require(ReplicatedStorage.shared.packages.Fusion.State.peek)

local Children = Fusion.Children
local peek = Fusion.peek
local OnEvent = Fusion.OnEvent
local OnChange = Fusion.OnChange
type UsedAs<T> = Fusion.UsedAs<T>

local function RegionView(
	scope: Fusion.Scope,
	props: {
		IsShown: UsedAs<boolean>,
		Region: UsedAs<string>,
		Ping: UsedAs<number>,
	}
)
	
	return scope:Shadow(props.IsShown, scope:New "Frame" {
		Name = "Region",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.00521, 0.907),
		Size = UDim2.fromScale(0.149, 0.0926),

		[Children] = {
			scope:New "TextLabel" {
				Name = "Region",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,	
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.45, 0.587),
				Size = UDim2.fromScale(0.723, 0.37),
				Text = props.Region,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextWrapped = true,
				ZIndex = 3,

				[Children] = {
					scope:New "UIStroke" {
						Name = "UIStroke",
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.07,
					},

					scope:New "UIAspectRatioConstraint" {
						Name = "UIAspectRatioConstraint",
						AspectRatio = 5.56,
					},

					scope:New "UITextSizeConstraint" {
						Name = "UITextSizeConstraint",
						MaxTextSize = 24,
					},
				}
			},

			scope:New "TextLabel" {
				Name = "Ping",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				FontFace = Font.new(
					"rbxasset://fonts/families/GothamSSm.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				Position = UDim2.fromScale(0.45, 0.812),
				Size = UDim2.fromScale(0.723, 0.22),
				Text = scope:Computed(function(use)
					return `Ping - {math.floor(use(props.Ping))}ms`
				end),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextWrapped = true,
				ZIndex = 3,

				[Children] = {
					scope:New "UIStroke" {
						Name = "UIStroke",
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.07,
					},

					scope:New "UIAspectRatioConstraint" {
						Name = "UIAspectRatioConstraint",
						AspectRatio = 9.36,
					},

					scope:New "UITextSizeConstraint" {
						Name = "UITextSizeConstraint",
						MaxTextSize = 20,
					},
				}
			},

			scope:New "UIAspectRatioConstraint" {
				Name = "UIAspectRatioConstraint",
				AspectRatio = 2.85,
			},
		}
	})
end

return RegionView