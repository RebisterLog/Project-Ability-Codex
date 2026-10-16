--!strict
--- `Sequencer` stand-in: a sequence driven by the test.
---
--- The real `Sequencer` ticks off `RunService.Heartbeat` and moves
--- `CurrentFrame` by `Speed * delta * 60`. None of that is here: frames are
--- moved by `world:Step(n)`, so the test decides when a hit lands, not the
--- weather.
---
--- Fidelity is needed in exactly one respect — which entries fire at all. The
--- entry `{20, fn, 24}` means "fn on every frame from 20 through 24", while
--- `{30}` is simply the end. Getting this arithmetic wrong changes the skill's
--- entire timing, which is why the tests check it.
---
--- The frame number in the log comes from here rather than from the clock:
--- recomputing `math.floor(time * 60)` produced "29" where the skill dropped
--- its armor on frame 30.

local Butler = require("./Butler")

local Sequence = {}
Sequence.__index = Sequence

type Frame = { any }

function Sequence.new(data: { [string]: any }, trace: any): any
	local frames: { Frame } = data.Frames or {}
	local numbers: { number } = {}

	for _, entry in frames do
		table.insert(numbers, entry[1] :: number)

		if type(entry[3]) == "number" then table.insert(numbers, entry[3] :: number) end
	end

	table.sort(numbers)

	local self = setmetatable({
		data = data,
		trace = trace,
		frames = frames,
		first = if #numbers > 0 then numbers[1] else 0,
		last = if #numbers > 0 then numbers[#numbers] else 0,
		current = 0,
		playing = false,
		finished = false,
		Speed = data.Speed or 1,
		Cleaner = Butler.new("sequence"),
		fired = {},
	}, Sequence)

	return self
end

--- An entry fires on frame `frame` if its number equals that frame or the frame
--- falls inside its loop.
local function matches(entry: Frame, frame: number): boolean
	local start = entry[1] :: number
	local stop = entry[3]

	if type(stop) == "number" then return frame >= start and frame <= stop end

	return frame == start
end

--- Advances the sequence by `count` frames. `Validate`, if present, is checked
--- on every frame: that is how a skill can interrupt itself.
function Sequence.Step(self: any, count: number)
	if not self.playing then return end

	for _ = 1, count do
		self.current += 1

		if self.trace then self.trace:setFrame(self.current) end

		if self.data.Validate and not self.data.Validate() then
			self:Stop()
			return
		end

		for index, entry in self.frames do
			if matches(entry, self.current) then
				local callback = entry[2]

				if type(callback) == "function" then
					table.insert(self.fired, { frame = self.current, index = index })
					callback(self, self.current)
				end
			end
		end

		if self.current >= self.last then
			self.playing = false
			self.finished = true
			self.Cleaner:Clean()

			if self.trace then self.trace:setFrame(self.current) end

			return
		end
	end
end

function Sequence.Play(self: any)
	if self.playing then return end

	self.current = self.first - 1
	self.playing = true
	self.finished = false
end

--- `Await` returns straight away in a test: the sequence does not run on its
--- own, the test scrolls through its frames. So `Activate` never blocks and can
--- do what it does after the wait — bump the combo counter, for instance.
function Sequence.Await(self: any): string
	if self.finished then return "Finished" end
	if self.playing then return "Playing" end

	return "Stopped"
end

function Sequence.Stop(self: any)
	if not self.playing and not self.finished then return end

	self.playing = false
	self.Cleaner:Clean()
end

function Sequence.Pause(self: any)
	self.playing = false
end

function Sequence.AdjustSpeed(self: any, speed: number)
	self.Speed = math.clamp(speed, 0, 10)
end

function Sequence.IsPlaying(self: any): boolean
	return self.playing
end

function Sequence.Destroy(self: any)
	self.playing = false
	self.Cleaner:Destroy()
end

return Sequence
