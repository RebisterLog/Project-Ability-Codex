--!strict
--!native
--!optimize 2

const Actor = script:GetActor()

const Tracks: { [Animator]: { [Animation]: AnimationTrack } } = {}

-- Speed of every track currently held at zero by a Time Stop. A track already
-- in the map is skipped by a later hold — the first one owns the restore.
const HeldSpeeds: { [AnimationTrack]: number } = {}

-- Hold every playing clip of `models` at speed zero, remembering each
-- track's speed. Tracks already held (Speed == 0) are skipped.
const function pauseModels(models: { Model })
	for _, character in models do
		if typeof(character) ~= "Instance" then continue end
		if not character:IsA("Model") then continue end

		const animator = character:FindFirstChildWhichIsA("Animator", true)
		if not animator then continue end

		for _, track in animator:GetPlayingAnimationTracks() do
			if HeldSpeeds[track] ~= nil then continue end
			if track.Speed == 0 then continue end
			HeldSpeeds[track] = track.Speed
			track:AdjustSpeed(0)
		end
	end
end

-- Hand the remembered speeds back to the still-alive tracks and forget the
-- rest.
const function resumeModels(models: { Model })
	for _, character in models do
		if typeof(character) ~= "Instance" then continue end
		if not character:IsA("Model") then continue end

		const animator = character:FindFirstChildWhichIsA("Animator", true)
		if not animator then continue end

		for _, track in animator:GetPlayingAnimationTracks() do
			const speed = HeldSpeeds[track]
			if speed == nil then continue end

			HeldSpeeds[track] = nil
			track:AdjustSpeed(speed)
		end
	end
end

Actor:BindToMessage("PauseAll", function(models: { Model }?)
	if type(models) ~= "table" then return end
	pauseModels(models)
end)

Actor:BindToMessage("ResumeAll", function(models: { Model }?)
	if type(models) ~= "table" then return end
	resumeModels(models)
end)

type AnimationsPlayProps = {
	Priority: Enum.AnimationPriority?,
	Speed: number?,
	FadeInTime: number?,
	Weight: number?,
}
Actor:BindToMessage(
	"Play",
	function(character: Model, animation: Animation, props: AnimationsPlayProps?)
		const animator = character:FindFirstChildWhichIsA("Animator", true)
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

		if Tracks[animator][animation] then
			Tracks[animator][animation]:Play(props.FadeInTime, props.Weight, props.Speed)
		else
			Tracks[animator][animation] = animator:LoadAnimation(animation)
			Tracks[animator][animation]:Play(props.FadeInTime, props.Weight, props.Speed)
		end
	end
)

type AnimationsStopProps = {
	FadeOutTime: number?,
}
Actor:BindToMessage(
	"Stop",
	function(character: Model, animation: Animation, props: AnimationsStopProps?)
		const animator = character:FindFirstChildWhichIsA("Animator", true)
		if not animator then return end

		if not Tracks[animator] or not Tracks[animator][animation] then return end

		props = props or {
			FadeOutTime = 0,
		}

		Tracks[animator][animation]:Stop(props.FadeOutTime)
	end
)
