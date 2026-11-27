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

type DashData = {
	Character: Model?,
	SpecData: SpecData?,
	-- The movement direction of the dash; the effect turns it into one of the four
	-- animation directions.
	Normal: Vector3?,
}

function Dash:Validate(data: DashData)
	const character = data.Character
	if not character then return false end
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

function Dash.onStart(self: typeof(Dash), data: DashData)
	const character, specData, normal = data.Character, data.SpecData, data.Normal
	if not (character and specData and normal) then return end

	const direction = GetDashDirection(normal)
	self.PlayAnimation(character, specData, direction)
end

return Dash
