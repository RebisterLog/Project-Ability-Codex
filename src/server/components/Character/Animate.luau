--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CoreAnimations = {
	Idle = Enum.AnimationPriority.Idle,
	Walk = Enum.AnimationPriority.Movement,
	Run = Enum.AnimationPriority.Movement,
	Jump = Enum.AnimationPriority.Action,
	FreeFall =  Enum.AnimationPriority.Core,
	GettingUp = Enum.AnimationPriority.Action,
	Platformstand = Enum.AnimationPriority.Idle,
	Landed = Enum.AnimationPriority.Movement,

	Seat = Enum.AnimationPriority.Idle,
	Climb = Enum.AnimationPriority.Core,
	ToolNone = Enum.AnimationPriority.Idle,
}

return function(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local animator = humanoid:WaitForChild("Animator") :: Animator
	local rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart

	local MovementAnimations: {[keyof<typeof(CoreAnimations)>]: Animation} = {}
	local MovementTracks: {[keyof<typeof(CoreAnimations)>]: AnimationTrack} = {}
	local PlayingTracks: {[keyof<typeof(CoreAnimations)>]: AnimationTrack} = {}

	local function loadAnimation(name: string, id: string)
		local animation = Instance.new("Animation")
		animation.Name = name
		animation.AnimationId = id

		local track = animator:LoadAnimation(animation)
		track.Priority = CoreAnimations[name]

		animation:Destroy()

		MovementTracks[name] = track
	end

	local function transitToAnimation(name: keyof<typeof(CoreAnimations)>, fadeTime: number?, weight: number?, speed: number?)
		local track = MovementTracks[name]
		if not track then return end

		local oldTrack = PlayingTracks[name]
		if oldTrack == track and oldTrack.IsPlaying then
			if speed then oldTrack:AdjustSpeed(speed) end
			if weight then oldTrack:AdjustWeight(weight) end
			return
		end

		for i, track in PlayingTracks do
			if track.Priority == Enum.AnimationPriority.Action then
				continue
			end

			track:Stop(0.25)
		end

		if track.Priority ~= Enum.AnimationPriority.Action then
			PlayingTracks[name] = track
		end

		track:Play(fadeTime, weight, speed)
	end

	local function playAnimation(name: keyof<typeof(CoreAnimations)>, fadeTime: number?, weight: number?, speed: number?)
		local track = MovementTracks[name]
		if not track then return end

		track:Play(fadeTime, weight, speed)
	end

	local function stopAnimation(name: keyof<typeof(CoreAnimations)>, fadeTime: number?)
		local track = MovementTracks[name]
		if not track then return end

		track:Stop(fadeTime)
	end

	local function stopAllAnimations()
		for i, track in PlayingTracks do
			track:Stop()
		end
	end

	local function getRigScale()
		return rootPart.Size.Y / 2
	end

	local jumpDelay: thread?
	local jumpTime = 0
	humanoid.StateChanged:Connect(function(old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
		--print(`NEW: {new.Name} \t OLD: {old.Name}`)

		if old == Enum.HumanoidStateType.Physics then
			transitToAnimation("GettingUp")
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end

		if new == Enum.HumanoidStateType.Physics then
			stopAllAnimations()

			if MovementTracks["Idle"] then
				MovementTracks["Idle"]:Stop()
			end
		end

		if new == Enum.HumanoidStateType.PlatformStanding then
			stopAllAnimations()
			if MovementTracks["Idle"] then
				MovementTracks["Idle"]:Stop()
			end
			return
		end

		if new == Enum.HumanoidStateType.Freefall then
			if old == Enum.HumanoidStateType.Jumping then
				jumpTime = tick()
				playAnimation("Jump")
			end

			jumpDelay = task.delay(MovementTracks["Jump"] and MovementTracks["Jump"].Length * 0.5 or 0, function()
				transitToAnimation("FreeFall")
			end)
		end

		if new == Enum.HumanoidStateType.Landed then
			if jumpDelay then
				task.cancel(jumpDelay)
			end

			stopAnimation("FreeFall", 0.2)

			if tick() - jumpTime > 2 then
				playAnimation("Landed", 0.2)
			end
		end
	end)

	RunService.Heartbeat:Connect(function()
		local speed = (rootPart.AssemblyLinearVelocity * Vector3.new(1,0,1)).Magnitude 

		speed /= getRigScale()

		if speed > 20 then
			transitToAnimation("Run", 0.25, nil, speed/24)
		elseif speed > 1 then
			transitToAnimation("Walk", 0.25,  nil, speed/12)
		elseif math.floor(speed) == 0 then
			transitToAnimation("Idle", 0.5)
		end
	end)

	humanoid.Died:Once(function()
		for i, track in animator:GetPlayingAnimationTracks() do track:Stop(); track:Destroy() end
		PlayingTracks = {}
	end)

	local function connectAnimationByAttribute(attribute: string, id: string)
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

	for i, track in animator:GetPlayingAnimationTracks() do track:Stop(); track:Destroy() end

	character.AttributeChanged:Connect(function(attr)
		connectAnimationByAttribute(attr, character:GetAttribute(attr))
	end)

	for attribute, id in character:GetAttributes() do
		connectAnimationByAttribute(attribute, id)
	end

	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
end