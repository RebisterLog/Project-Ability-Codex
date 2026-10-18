--!native
--!optimize 2

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

const CoreAnimations = {
	Idle = Enum.AnimationPriority.Idle,
	Walk = Enum.AnimationPriority.Movement,
	Run = Enum.AnimationPriority.Movement,
	Jump = Enum.AnimationPriority.Action,
	FreeFall = Enum.AnimationPriority.Core,
	GettingUp = Enum.AnimationPriority.Action,
	Platformstand = Enum.AnimationPriority.Idle,
	Landed = Enum.AnimationPriority.Movement,

	Seat = Enum.AnimationPriority.Idle,
	Climb = Enum.AnimationPriority.Core,
	ToolNone = Enum.AnimationPriority.Idle,
}

return function(character: Model)
	const animationController = character:WaitForChild("AnimationController") :: Humanoid
	const animator = animationController:WaitForChild("Animator") :: Animator
	const rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart

	const MovementAnimations: { [keyof<typeof(CoreAnimations)>]: Animation } = {}
	const MovementTracks: { [keyof<typeof(CoreAnimations)>]: AnimationTrack } = {}
	const PlayingTracks: { [keyof<typeof(CoreAnimations)>]: AnimationTrack } = {}

	const loadAnimation = function(name: string, id: string)
		const animation = Instance.new("Animation")
		animation.Name = name
		animation.AnimationId = id

		const track = animator:LoadAnimation(animation)
		track.Priority = CoreAnimations[name]

		animation:Destroy()

		MovementTracks[name] = track
	end

	const transitToAnimation = function(
		name: keyof<typeof(CoreAnimations)>,
		fadeTime: number?,
		weight: number?,
		speed: number?
	)
		const track = MovementTracks[name]
		if not track then return end

		const oldTrack = PlayingTracks[name]
		if oldTrack == track and oldTrack.IsPlaying then
			if speed then oldTrack:AdjustSpeed(speed) end
			if weight then oldTrack:AdjustWeight(weight) end
			return
		end

		for i, track in PlayingTracks do
			if track.Priority == Enum.AnimationPriority.Action then continue end

			track:Stop(0.25)
		end

		if track.Priority ~= Enum.AnimationPriority.Action then PlayingTracks[name] = track end

		track:Play(fadeTime, weight, speed)
	end

	const playAnimation = function(
		name: keyof<typeof(CoreAnimations)>,
		fadeTime: number?,
		weight: number?,
		speed: number?
	)
		const track = MovementTracks[name]
		if not track then return end

		track:Play(fadeTime, weight, speed)
	end

	const stopAnimation = function(name: keyof<typeof(CoreAnimations)>, fadeTime: number?)
		const track = MovementTracks[name]
		if not track then return end

		track:Stop(fadeTime)
	end

	const stopAllAnimations = function()
		for i, track in PlayingTracks do
			track:Stop()
		end
	end

	const getRigScale = function()
		return rootPart.Size.Y / 2
	end

	RunService.Heartbeat:Connect(function()
		local speed = (rootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude

		speed /= getRigScale()

		if speed > 20 then
			transitToAnimation("Run", 0.1, nil, speed / 24)
		elseif speed > 1 then
			transitToAnimation("Walk", 0.1, nil, speed / 12)
		elseif math.floor(speed) == 0 then
			transitToAnimation("Idle", 0.1)
		end
	end)

	const connectAnimationByAttribute = function(attribute: string, id: string)
		if not CoreAnimations[attribute] then return end
		if MovementAnimations[attribute] then return end
		if MovementTracks[attribute] then return end

		if PlayingTracks[attribute] then
			PlayingTracks[attribute]:Stop()
			PlayingTracks[attribute]:Destroy()
		end

		MovementAnimations[attribute] = id
		if MovementTracks[attribute] then MovementTracks[attribute]:Destroy() end

		loadAnimation(attribute, id)
	end

	for i, track in animator:GetPlayingAnimationTracks() do
		track:Stop()
		track:Destroy()
	end

	character.AttributeChanged:Connect(function(attr)
		connectAnimationByAttribute(attr, character:GetAttribute(attr))
	end)

	for attribute, id in character:GetAttributes() do
		connectAnimationByAttribute(attribute, id)
	end
end
