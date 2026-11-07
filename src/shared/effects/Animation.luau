const AnimationActor = game.Players.LocalPlayer.PlayerScripts.client.Animations

const Animation = {}

--- The clip as the skins and the skill configs carry it.
type AnimationClip = {
	Animation: Animation,
	Priority: Enum.AnimationPriority?,
	FadeInTime: number?,
	Weight: number?,
	Overlay: boolean?,
}

type AnimationData = {
	-- "AdjustSpeed" retimes a track that is already playing, which a fresh "Play"
	-- cannot do without restarting it.
	-- "PauseAll" / "ResumeAll" hold (and release) every playing clip of the
	-- given models at once, without addressing individual tracks — used by
	-- Time Stop so a frozen world stops moving.
	Type: "Play" | "AdjustSpeed" | "PauseAll" | "ResumeAll",
	Character: Model?,
	Animation: AnimationClip?,
	Speed: number?,
	-- Roblox keeps looping on the track, not on the Animation asset.
	Looped: boolean?,
	AdjustSpeed: number?,
	-- PauseAll / ResumeAll only.
	Characters: { Model }?,
}

type AnimationStopData = {
	Character: Model,
	-- The raw asset: stopping addresses the track, not the clip it was built from.
	Animation: Animation?,
	FadeTime: number?,
	Overlay: boolean?,
}

function Animation:Validate(data: AnimationData)
	if data.Type == "PauseAll" or data.Type == "ResumeAll" then
		return typeof(data.Characters) == "table"
	end

	const character = data.Character
	if not character then return false end
	if character.ClassName ~= "Model" then return false end

	if
		(character:GetPivot().Position - workspace.CurrentCamera.CFrame.Position).Magnitude > 150
	then
		return false
	end
	return true
end

function Animation:onStart(data: AnimationData)
	const character = data.Character
	const clip = data.Animation

	if data.Type == "PauseAll" or data.Type == "ResumeAll" then
		AnimationActor:SendMessage(data.Type, data.Characters)
		return
	end
	if not clip then return end
	if data.Type == "AdjustSpeed" then
		if character == nil then return end
		AnimationActor:SendMessage("AdjustSpeed", character, clip.Animation, data.AdjustSpeed)
		return
	end
	if character == nil then return end
	AnimationActor:SendMessage("Play", character, clip.Animation, {
		Speed = data.Speed,
		Priority = clip.Priority,
		FadeInTime = clip.FadeInTime,
		Weight = clip.Weight,
		Looped = data.Looped,
		Overlay = clip.Overlay,
	})
end

function Animation:onStop(data: AnimationStopData)
	const animation = data.Animation

	if not animation then return end

	AnimationActor:SendMessage("Stop", data.Character, animation, {
		FadeOutTime = data.FadeTime,
		Overlay = data.Overlay,
	})
end

return Animation
