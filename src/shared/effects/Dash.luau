const ReplicatedStorage = game:GetService("ReplicatedStorage")
const AnimationActor = game.Players.LocalPlayer.PlayerScripts.client.Animations
const Skins = require(ReplicatedStorage.shared.configs.Skins)
const Camera = workspace.CurrentCamera

const Dash = {}

@native
local function GetDashDirection(Normal)
	const angle = math.ceil(math.deg(math.atan2(Normal.X, -Normal.Z)) - 0.5)

	if angle > 55 and angle < 125 then
		return "Right"
	elseif angle < -55 and angle > -125 then
		return "Left"
	elseif angle <= -125 or angle >= 125 then
		return "Back"
	end
	return "Forward"
end

type SpecData = {
	SpecId: string,
	SkinId: string,
}

type Directions = "Forward" | "Back" | "Left" | "Right"

function Dash:Validate(character: Model)
	const primaryPart = character.PrimaryPart
	if not primaryPart then return false end

	if not workspace.CurrentCamera then return false end

	if (primaryPart.Position - workspace.CurrentCamera.CFrame.Position).Magnitude > 50 then
		return false
	end

	return true
end

function Dash.PlayAnimation(Character: Model, SpecData: SpecData, Direction: Directions)
	const SpecId = SpecData.SpecId
	const SkinId = SpecData.SkinId or "None"

	if not Skins[SpecId] then return end
	if not Skins[SpecId][SkinId] then return end

	const AnimData = (Skins[SpecId][SkinId].Animations or {})["Dash" .. Direction]

	AnimationActor:SendMessage("Play", Character, AnimData.Animation, {
		Priority = AnimData.Priority,
		Speed = AnimData.Speed,
	})
end

function Dash.onStart(self: typeof(Dash), Character: Model, SpecData: SpecData, Normal: Vector3)
	const direction = GetDashDirection(Normal)
	self.PlayAnimation(Character, SpecData, direction)
end

return Dash
