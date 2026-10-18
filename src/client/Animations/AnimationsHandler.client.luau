--!strict
--!native
--!optimize 2

const Actor = script:GetActor()

const Tracks: { [Animator]: { [Animation]: AnimationTrack } } = {}

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
