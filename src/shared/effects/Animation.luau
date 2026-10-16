const ReplicatedStorage = game:GetService("ReplicatedStorage")
const AnimationActor = game.Players.LocalPlayer.PlayerScripts.client.Animations
const Skins = require(ReplicatedStorage.shared.configs.Skins)

const Animation = {}

type Data = {
	Animation: {
		Animation: Animation,
		Priority: Enum.AnimationPriority?,
	},
	Speed: number?,
}

type StopData = {
	Animation: Animation,
	FadeTime: number?,
}

function Animation:Validate(character: Model)
	if character.ClassName ~= "Model" then return end
	if not character then return false end

	if
		(character:GetPivot().Position - workspace.CurrentCamera.CFrame.Position).Magnitude > 150
	then
		return false
	end
	return true
end

function Animation:onStart(character: Model, Data: Data)
	const Animation = Data.Animation

	if not Animation then return end

	AnimationActor:SendMessage("Play", character, Animation.Animation, {
		Speed = Data.Speed,
		Priority = Animation.Priority,
		FadeInTime = Animation.FadeInTime,
		Weight = Animation.Weight,
	})
end

function Animation:onStop(character: Model, Data: StopData)
	const Animation = Data.Animation

	if not Animation then return end

	AnimationActor:SendMessage("Stop", character, Animation, {
		FadeOutTime = Data.FadeTime,
	})
end

return Animation
