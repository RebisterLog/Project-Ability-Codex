const Tracks: { [Animator]: { [Animation]: AnimationTrack } } = {}

-- Speed of every track currently held at zero by a bulk pause. A track already
-- in the map is skipped by a later hold — the first one owns the restore.
const HeldSpeeds: { [AnimationTrack]: number } = {}

const Animation = {}

--- The clip as the skins and the skill configs carry it.
type AnimationClip = {
	Animation: Animation,
	Priority: Enum.AnimationPriority?,
	FadeInTime: number?,
	Weight: number?,
	Looped: boolean?,
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

type AnimationsPlayProps = {
	Priority: Enum.AnimationPriority?,
	Speed: number?,
	FadeInTime: number?,
	Weight: number?,
	Looped: boolean?,
	Overlay: boolean?,
}

type AnimationsStopProps = {
	FadeOutTime: number?,
	Overlay: boolean?,
}

const function getAnimator(character: Model): Animator?
	if typeof(character) ~= "Instance" or not character:IsA("Model") then return nil end
	return character:FindFirstChildWhichIsA("Animator", true)
end

const function pauseModels(models: { Model })
	for _, character in models do
		const animator = getAnimator(character)
		if not animator then continue end

		for _, track in animator:GetPlayingAnimationTracks() do
			if HeldSpeeds[track] ~= nil then continue end
			if track.Speed == 0 then continue end
			HeldSpeeds[track] = track.Speed
			track:AdjustSpeed(0)
		end
	end
end

const function resumeModels(models: { Model })
	for _, character in models do
		const animator = getAnimator(character)
		if not animator then continue end

		for _, track in animator:GetPlayingAnimationTracks() do
			const speed = HeldSpeeds[track]
			if speed == nil then continue end

			HeldSpeeds[track] = nil
			track:AdjustSpeed(speed)
		end
	end
end

function Animation.Play(character: Model, animation: Animation, props: AnimationsPlayProps?)
	const animator = getAnimator(character)
	if not animator then return end

	props = props
		or {
			Priority = Enum.AnimationPriority.Action,
			Speed = 1,
			FadeInTime = 0,
			Weight = 1,
		}

	if not Tracks[animator] then
		Tracks[animator] = {}

		animator.Destroying:Once(function()
			Tracks[animator] = nil
		end)
	end

	const track = Tracks[animator][animation] or animator:LoadAnimation(animation)
	Tracks[animator][animation] = track
	track.Looped = props.Looped == true
	track:Play(props.FadeInTime, props.Weight, props.Speed)
end

function Animation.Stop(character: Model, animation: Animation, props: AnimationsStopProps?)
	const animator = getAnimator(character)
	if not animator then return end

	if not Tracks[animator] or not Tracks[animator][animation] then return end

	props = props or { FadeOutTime = 0 }

	const track = Tracks[animator][animation]
	HeldSpeeds[track] = nil
	track:Stop(props.FadeOutTime)
end

function Animation.AdjustSpeed(character: Model, animation: Animation, speed: number?)
	const animator = getAnimator(character)
	if not animator then return end

	const tracks = Tracks[animator]
	const track = tracks and tracks[animation]
	if not track or speed == nil then return end

	track:AdjustSpeed(speed)
end

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
		if type(data.Characters) ~= "table" then return end
		if data.Type == "PauseAll" then
			pauseModels(data.Characters)
		else
			resumeModels(data.Characters)
		end
		return
	end
	if not clip then return end
	if data.Type == "AdjustSpeed" then
		if character == nil then return end
		Animation.AdjustSpeed(character, clip.Animation, data.AdjustSpeed)
		return
	end
	if character == nil then return end
	Animation.Play(character, clip.Animation, {
		Speed = data.Speed,
		Priority = clip.Priority,
		FadeInTime = clip.FadeInTime,
		Weight = clip.Weight,
		Looped = clip.Looped,
		Overlay = clip.Overlay,
	})
end

function Animation:onStop(data: AnimationStopData)
	const animation = data.Animation

	if not animation then return end

	Animation.Stop(data.Character, animation, {
		FadeOutTime = data.FadeTime,
		Overlay = data.Overlay,
	})
end

return Animation
