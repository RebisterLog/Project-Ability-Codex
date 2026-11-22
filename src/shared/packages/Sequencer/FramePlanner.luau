--!strict

--[[
	Pure scheduling helper for Sequencer.

	It owns the only piece of the sequencer that must be exact: which integer
	frames were crossed between two Heartbeat ticks, and which frame entries
	fire on each of them. No Roblox services, no state, no side effects — so the
	frame math can be tested under Lune with simulated `delta` values.

	Frame entries keep the positional form `{start, callback, end}` and may add
	two optional keys:

		Interval = N   fire every N frames inside the ranged entry (default 1)
		Offset   = M   shift the first fire M frames past `start` (default 0)

	So `{40, fn, 60, Interval = 6, Offset = 6}` fires on 46, 52 and 58, while
	`{25, fn, 150, Interval = 5}` fires on 25, 30, ... 150.
]]

export type Frame = {
	[number]: any,
	Interval: number?,
	Offset: number?,
}

export type PlannedFrame = {
	Frame: number,
	Entry: Frame,
}

const FramePlanner = {}

local function isInteger(value: any): boolean
	return type(value) == "number" and value % 1 == 0
end

--- Validates one frame entry. Returns a reason on failure, nil on success.
local function validateEntry(entry: Frame): string?
	if type(entry) ~= "table" then return "frame entry must be a table" end

	const start = entry[1]
	if not isInteger(start) then return "frame entry needs an integer start frame" end

	const finish = entry[3]
	if finish ~= nil then
		if not isInteger(finish) then return "frame end must be an integer" end
		if (finish :: number) < (start :: number) then return "frame end is before its start" end
	end

	const callback = entry[2]
	if callback ~= nil and typeof(callback) ~= "function" then
		return "frame callback must be a function"
	end

	if entry.Interval ~= nil then
		if not isInteger(entry.Interval) or (entry.Interval :: number) < 1 then
			return "Interval must be a positive integer"
		end
	end

	if entry.Offset ~= nil then
		if not isInteger(entry.Offset) or (entry.Offset :: number) < 0 then
			return "Offset must be a non-negative integer"
		end
	end

	return nil
end

--- Checks the whole frame list once, at construction time.
function FramePlanner.Validate(frames: { Frame }): (boolean, string?)
	if type(frames) ~= "table" or #frames == 0 then return false, "Frames must be a non-empty array" end

	for index, entry in frames do
		if type(index) ~= "number" then continue end

		const reason = validateEntry(entry)
		if reason then return false, `Frames[{index}]: {reason}` end
	end

	return true, nil
end

--- The last frame the queue can reach. Used to bound catch-up after a hitch.
function FramePlanner.LastFrame(frames: { Frame }): number
	local last = 0

	for _, entry in frames do
		const start = entry[1] :: number
		if start > last then last = start end

		const finish = entry[3] :: number?
		if finish and finish > last then last = finish end
	end

	return last
end

local function matches(entry: Frame, frame: number): boolean
	const start = entry[1] :: number
	const first = start + (entry.Offset or 0)

	if entry[3] == nil then
		-- A single-frame entry fires exactly once, even with an Offset.
		return frame == first
	end

	const finish = entry[3] :: number
	if frame < first or frame > finish then return false end

	return (frame - first) % (entry.Interval or 1) == 0
end

--- Expands the frames crossed between `low` (previous playhead) and `high`
--- (current playhead) into one item per real frame, in crossing order.
--- Frames already executed (`<= lastExecuted`) are never returned twice, and
--- nothing past `lastFrame` is planned — one huge tick replays every crossed
--- frame up to the end of the queue instead of dropping the whole window.
function FramePlanner.Plan(
	frames: { Frame },
	low: number,
	high: number,
	lastExecuted: number,
	lastFrame: number
): { PlannedFrame }
	const planned: { PlannedFrame } = {}
	const first = math.floor(low)
	const last = math.min(math.floor(high), lastFrame)

	for frame = first, last do
		if frame <= lastExecuted then continue end

		for _, entry in frames do
			if matches(entry, frame) then
				table.insert(planned, { Frame = frame, Entry = entry })
			end
		end
	end

	return planned
end

return FramePlanner
