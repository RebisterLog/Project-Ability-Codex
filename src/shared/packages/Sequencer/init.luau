--!strict
--!native
--!optimize 2

--[[
╔══════════════════════════════════════════════════════════════════════════════╗
║                           S E Q U E N C E R   V.1.0.0                        ║
║                          by RebisterLog (Srat_hochu228)                      ║
╚══════════════════════════════════════════════════════════════════════════════╝

Special thanks to author of Butler DexxterDax!
https://github.com/DexxterDax/Butler

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  WHAT IS SEQUENCER?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	It's the module that was developed to solve the problem of 
	orderly execution of functions in a single, independent object.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  DESCRIPTION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	For greater precision, the primary unit of measurement is 1 frame, 
	where 60 frames equal 1 second.
	
	(60 frames = 1 second)
	
	This simple module is very convenient for personal code correction and additions.
	If you need to add an additional method to the class, you CAN do so without any doubt,
	as this would contradict the module's philosophy. 
	
	The class object also supports validation before each iteration of the function call.
	This is a crucial feature, allowing the entire queue to be safely stopped if validation 
	fails before any of its steps.
	
	Support for calling a function over multiple frames is included, eliminating the need to
	duplicate code and simply repeating the same function call for the required number of frames.
	
	(1 frame = 1 function call)
	
	A special Cleaner object is created within each object, which self-cleans whenever 
	the parent object is stopped. This allows objects to be added within the queue functions 
	that need to be cleaned up after the entire queue is completed. 
	
	Another important feature is the ability to set the queue playback speed,
	which allows you to speed up and slow down the execution of functions,
	making the class itself more flexible and robust.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  API
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

	Sequencer.new                             → Sequencer
	Sequencer.States                          → States
	
	───Core methods─────────────────────────────────────────────────────────
	sequencer:Play()                          
	sequencer:Stop()
	sequencer:Pause()
	
	───Signals and awaits───────────────────────────────────────────────────
	sequencer:Await(state: State?)

	───Utils────────────────────────────────────────────────────────────────
	sequencer:AdjustSpeed(speed: number)
	sequencer:IsPlaying()                     → boolean
	
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  EXAMPLE OF USE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
	local Sequencer = require(PATH_TO_MODULE)

	local sequencer = Sequencer.new({ 
		Validator = function(self)
			return true
		end,

		Frames = {
			{0, function()
				print("Start")
			end},

			{10,
				function(self, currentFrame: number)
					print("Frame: "..currentFrame)
				end,
			20},

			{120, function()
				print("End")
			end},
		},
	})


	task.wait(5)
	sequencer:Play()

	sequencer:Await()
	print("Done")

	sequencer:Play()
	sequencer:Await()
	print("Done 2")
]]

-- SERVICES
local RunService = game:GetService("RunService")

-- REQUIRES
local Butler = require(script.Butler)
local FramePlanner = require(script.FramePlanner)

-- CONSTANTS
const MINIMAL_POSSIBLE_SPEED = 0
const MAXIMUM_POSSIBLE_SPEED = 10

-- ENUMS
const States = {
	None = -1,
	Playing = 0,
	Paused = 1,
	Stopped = 2,
}

-- TYPES
export type States = typeof(States)
export type State = number

type Cleaner = typeof(Butler.new())

--[[@Frame
	Default use:
	```lua
		--Start frame is 0
		{0, function()
		
		end}
		
		-- Only per 1 frame
		{15, function(self)
		
		end},
		
		-- From 30 to 40 frame (calls method every frame)
		{30,
		function(self, currentFrame: number)
		
		end,
		40},
		
		-- Every 6 frames inside the window, starting 6 frames after 40:
		-- fires on 46, 52 and 58
		{40,
		function(self, currentFrame: number)
		
		end,
		60,
		Interval = 6,
		Offset = 6},
		
		-- End frame
		{60},
	```	

	`currentFrame` is always the exact frame being executed, never the frame at
	the end of the current Heartbeat tick. Multiple crossed frames are executed
	one by one even when a single tick spans them all.
]]
type FrameCallback = (self: Sequencer, currentFrame: number) -> ()
type Frame = FramePlanner.Frame

type InputData = {
	Frames: { Frame },

	Validator: ((self: Sequencer) -> boolean)?,
	Speed: number?,
}

-- MODULE
const Sequencer = {}
Sequencer.__index = Sequencer
Sequencer.__type = "Sequencer"

type SequencerProperties = InputData & {
	Speed: number,
	State: State,
	CurrentFrame: number,
	-- Last integer frame whose callbacks already ran. Prevents both duplicates
	-- and skips when `delta` accumulates a fractional part.
	LastExecutedFrame: number,
	-- Upper bound for catch-up after a hitch (the last declared frame).
	LastFrame: number,
	Cleaner: Cleaner,
	Tick: RBXScriptConnection?,
}

type SequencerMethods = {
	Play: (self: Sequencer) -> (),
	Stop: (self: Sequencer) -> (),
	Pause: (self: Sequencer) -> (),
	AdjustSpeed: (self: Sequencer, speed: number) -> (),
	IsPlaying: (self: Sequencer) -> boolean,
	IsPaused: (self: Sequencer) -> boolean,
	Await: (self: Sequencer, state: States?) -> (),
	Destroy: (self: Sequencer) -> (),
}

export type Sequencer = setmetatable<SequencerProperties & SequencerMethods, typeof(Sequencer)>

function Sequencer.Play(self: Sequencer)
	-- If was already playing
	if self.State == States.Playing then return end

	if self.State == States.Paused then
		self.State = States.Playing
		return
	end

	-- A fresh run after Stop starts from zero. Paused keeps the playhead.
	self.CurrentFrame = 0
	self.LastExecutedFrame = -1

	self.Tick = RunService.Heartbeat:Connect(function(delta: number)
		-- Skipping until playing
		if self.State ~= States.Playing then return end

		const startFrame = self.CurrentFrame
		self.CurrentFrame += self.Speed * delta * 60 -- 60 frames = 1 second

		-- Every crossed integer frame is executed once, with its own frame
		-- number — not the number at the end of this Heartbeat tick.
		const planned = FramePlanner.Plan(
			self.Frames,
			startFrame,
			self.CurrentFrame,
			self.LastExecutedFrame,
			self.LastFrame
		)

		local validatedFrame = self.LastExecutedFrame

		for _, item in planned do
			if item.Frame ~= validatedFrame then
				validatedFrame = item.Frame

				const validator = self.Validator :: ((self: Sequencer) -> boolean)?
				if validator and not validator(self) then
					-- Runtime check was failed
					self:Stop()
					return
				end
			end

			self.LastExecutedFrame = item.Frame

			const callback = item.Entry[2] :: FrameCallback?

			if not callback then
				-- Found end frame (e.x.: {30})
				self:Stop()
				return
			end

			callback(self, item.Frame)

			-- A callback (or a signal it fired) may have stopped the sequence.
			-- The rest of this batch must not run anymore.
			if self.State ~= States.Playing then return end
		end

		-- Checks the time of the last frame
		if self.CurrentFrame >= self.LastFrame or self.CurrentFrame <= 0 then
			self:Stop()
		end
	end)

	self.State = States.Playing
end

function Sequencer.Stop(self: Sequencer)
	-- Not started or already stopped
	if self.State == States.None or self.State == States.Stopped then return end

	self.State = States.Stopped
	self.CurrentFrame = 0

	-- I didn't add Tick connection to the Cleaner
	-- to split 'user' stuff and 'module' stuff
	if self.Tick then self.Tick:Disconnect() end

	self.Cleaner:Clean()
end

function Sequencer.Pause(self: Sequencer)
	-- If not playing - skip
	if self.State ~= States.Playing then return end
	self.State = States.Paused
end

function Sequencer.AdjustSpeed(self: Sequencer, speed: number)
	-- To safe set using bounds between MINIMUM and MAXIMUM speeds
	self.Speed = math.clamp(speed, MINIMAL_POSSIBLE_SPEED, MAXIMUM_POSSIBLE_SPEED)
end

-- Just public method to get sequence playing state
function Sequencer.IsPlaying(self: Sequencer)
	return self.State == States.Playing
end

-- Paused is distinct from Stopped: `Play` resumes from `CurrentFrame` only
-- while the state is Paused, and restarts the queue from the beginning after
-- a Stop. Callers that hand a sequence back must check this, not `IsPlaying`.
function Sequencer.IsPaused(self: Sequencer)
	return self.State == States.Paused
end

-- I hate Promise :)
function Sequencer.Await(self: Sequencer, state: State?)
	-- Default value
	state = state or States.Stopped

	if self.State == state then return end

	local thread = coroutine.running()

	local await: RBXScriptConnection
	await = RunService.Heartbeat:Connect(function()
		-- When state of sequence == required state - continue main thread
		if self.State == state then
			await:Disconnect()
			coroutine.resume(thread)
		end
	end)

	coroutine.yield()
end

function Sequencer.Destroy(self: Sequencer)
	self.State = States.Stopped
	self.CurrentFrame = 0
	self.LastExecutedFrame = -1

	if self.Tick then self.Tick:Disconnect() end

	self.Cleaner:Destroy()
end

-- CONSTRUCTOR
return {
	new = function(data: InputData)
		const valid, reason = FramePlanner.Validate(data.Frames)
		if not valid then error(`Sequencer.new: {reason}`, 2) end

		local self = setmetatable({
			-- From data
			Validator = data.Validator,
			Frames = data.Frames,
			Speed = data.Speed or 1,

			-- Private
			State = States.None,
			CurrentFrame = 0,
			LastExecutedFrame = -1,
			LastFrame = FramePlanner.LastFrame(data.Frames),
			Cleaner = Butler.new(),
		}, Sequencer)

		return self :: Sequencer
	end,

	States = States,
}
