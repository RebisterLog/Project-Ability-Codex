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
		
		-- End frame
		{60},
	```	
]]
type FrameCallback = (self: Sequencer, currentFrame: number) -> ()

type Frame = {
	[number]: number | FrameCallback?,
}

type InputData = {
	Frames: {Frame},
	
	Validator: ((self: Sequencer) -> (boolean))?,
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
	Cleaner: Cleaner,
	Tick: RBXScriptConnection?,
}

type SequencerMethods = {
	Play: (self: Sequencer) -> (),
	Stop: (self: Sequencer) -> (),
	AdjustSpeed: (self: Sequencer, speed: number) -> (),
	IsPlaying: (self: Sequencer) -> (boolean),
	Await: (self: Sequencer, state: States?) -> (),
	Destroy: (self: Sequencer) -> (),
}

export type Sequencer = setmetatable<SequencerProperties & SequencerMethods, typeof(Sequencer)>

local function GetFrames(frames: {Frame}, startFrame: number, endFrame: number): {Frame}
	local scoped: {Frame} = {}
	local low = math.min(startFrame, endFrame)
	local high = math.max(startFrame, endFrame)

	for i = 1, #frames do
		local frame = frames[i]
		local frameStart = frame[1] :: number
		local frameEnd = frame[3] :: number?

		if not frameEnd then
			-- Single frame / end frame: fire if we passed or landed on it this tick
			if frameStart >= low and frameStart <= high then
				table.insert(scoped, frame)
			end
		else
			-- Added 1 frame to include last frame
			if high < frameStart or high > frameEnd + 1 then continue end
			
			-- Count of passed frames for that period of time
			local count = math.floor(high) - math.floor(low)
			
			if count > 0 then
				-- Dublicating if was passed a lot
				for _ = 1, count do
					table.insert(scoped, frame)
				end
			end
		end
	end

	return scoped
end

function Sequencer.Play(self: Sequencer)
	-- If was already playing
	if self.State == States.Playing then return end
	
	if self.State == States.Paused then
		self.State = States.Playing
		return
	end
	
	self.Tick = RunService.Heartbeat:Connect(function(delta: number)
		-- Skipping until playing
		if self.State ~= States.Playing then return end

		local startFrame = self.CurrentFrame
		self.CurrentFrame += self.Speed * delta * 60 -- 60 frames = 1 second

		-- The frames that were passed between 'startFrame' and self.CurrentFrame
		local toExecFrames: {Frame} = GetFrames(self.Frames, startFrame, self.CurrentFrame)
		if #toExecFrames == 0 then return end

		for i=1, #toExecFrames do
			local validator = self.Validator :: ((self: Sequencer) -> (boolean))?
			if validator and not validator(self) then
				-- Runtime check was failed
				self:Stop()
				return
			end

			local frame = toExecFrames[i]

			local callback = frame[2] :: FrameCallback?

			if not callback then
				-- Found end frame (e.x.: {30})
				self:Stop()
				return
			else
				callback(self, math.floor(self.CurrentFrame))
			end
		end

		-- Checks the time of the last frame
		if self.CurrentFrame >= self.Frames[#self.Frames][1] or self.CurrentFrame <= 0 then
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

	if self.Tick then self.Tick:Disconnect() end

	self.Cleaner:Destroy()
end

-- CONSTRUCTOR
return {
	new = function(data: InputData)
		local self = setmetatable({
			-- From data
			Validator = data.Validator,
			Frames = data.Frames,
			Speed = data.Speed or 1,

			-- Private
			State = States.None,
			CurrentFrame = 0,
			Cleaner = Butler.new(),
		}, Sequencer)

		return self :: Sequencer
	end,
	
	States = States,
}