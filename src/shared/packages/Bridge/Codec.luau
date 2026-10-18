--!strict
--!optimize 2

--[[
	Codec for the Crane Bridge.

	A BindableEvent is a hostile transport. When a table crosses one:
		- its metatable is dropped (methods silently disappear)
		- non-string indices are converted to strings (arrays become "1", "2", ...)
		- the table is copied, so identity is lost

	So the Bridge never lets a live value cross. Everything is converted into a
	tagged, JSON-serializable plain table first, and Decode turns those tags back
	into real Roblox datatypes when an agent passes them back in as arguments.

	Instances are encoded as records rather than passed by reference, so the whole
	envelope stays serializable end to end. Decode resolves a record's Path, which
	keeps chained calls working: the agent reads Path off a result and sends it
	straight back.
]]

local Codec = {}

-- Limits. Every one of these exists because the payload has to fit in a single
-- BindableEvent argument without wrecking the channel or the reader.
local MAX_DEPTH = 6
local MAX_NODES = 500
local MAX_KEYS = 200
local MAX_STRING = 4096
local MAX_BYTES = 256

export type Options = {
	MaxDepth: number?,
	MaxNodes: number?,
}

type State = {
	nodes: number,
	seen: { [any]: boolean },
	MaxDepth: number,
	MaxNodes: number,
}

local function Truncated(reason: string, preview: string?): { [string]: any }
	local out: { [string]: any } = { __type = "Truncated", Reason = reason }
	if preview then out.Preview = preview end
	return out
end

local function EncodeNumber(value: number): any
	if value ~= value then return { __type = "number", Value = "nan" } end
	if value == math.huge then return { __type = "number", Value = "inf" } end
	if value == -math.huge then return { __type = "number", Value = "-inf" } end
	return value
end

local function EncodeString(value: string): any
	if #value <= MAX_STRING then return value end
	return {
		__type = "string",
		Length = #value,
		Preview = string.sub(value, 1, MAX_STRING),
	}
end

--- Names a function well enough for an agent to recognise it in a method list.
local function FunctionLabel(value: any): string
	local named = pcall(function()
		return debug.info(value, "n")
	end)
	if named and type(named) == "string" and #named > 0 then return named end

	local sourced = pcall(function()
		return debug.info(value, "s")
	end)
	if sourced and type(sourced) == "string" and #sourced > 0 then return sourced end

	return "anonymous"
end

local function SafeFullName(instance: Instance): string
	local ok, fullName = pcall(function()
		return instance:GetFullName()
	end)
	if ok and type(fullName) == "string" then return fullName end
	return instance.Name
end

local function EncodeInstance(value: Instance): { [string]: any }
	return {
		__type = "Instance",
		Name = value.Name,
		ClassName = value.ClassName,
		Path = SafeFullName(value),
		IsDestroyed = if value.Parent then false else true,
	}
end

local function EncodeBuffer(value: any): { [string]: any }
	local size = (value :: any).Size
	local bytes = {}
	for i = 0, math.min((size or 0) - 1, MAX_BYTES) do
		table.insert(bytes, string.format("%02X", value:byte(i)))
	end
	return { __type = "buffer", Size = size, Bytes = table.concat(bytes) }
end

local function EncodeNumberSequence(value: any): { [string]: any }
	local keypoints = {}
	for _, keypoint in value.Keypoints do
		table.insert(keypoints, {
			Time = keypoint.Time,
			Value = keypoint.Value,
			Envelope = keypoint.Envelope,
		})
	end
	return { __type = "NumberSequence", Keypoints = keypoints }
end

local function EncodeColorSequence(value: any): { [string]: any }
	local keypoints = {}
	for _, keypoint in value.Keypoints do
		table.insert(keypoints, {
			Time = keypoint.Time,
			Color = { R = keypoint.Color.R, G = keypoint.Color.G, B = keypoint.Color.B },
		})
	end
	return { __type = "ColorSequence", Keypoints = keypoints }
end

--- Converts a Roblox datatype into a tagged record.
--- Anything unrecognised degrades to a readable string rather than erroring,
--- because an agent is better served by "here is what I could not serialise"
--- than by a failed request.
local function EncodeDatatype(value: any, kind: string): { [string]: any }
	if kind == "EnumItem" then
		-- EnumType is a live Enum object whose .Name is not readable, so tostring
		-- is the only clean way to get "KeyCode" out of it. Putting the object
		-- itself in the payload would push a live value across the event.
		return {
			__type = "Enum",
			EnumType = if value.EnumType == nil then nil else tostring(value.EnumType),
			Name = value.Name,
		}
	elseif kind == "Vector3" then
		return { __type = "Vector3", X = value.X, Y = value.Y, Z = value.Z }
	elseif kind == "Vector2" then
		return { __type = "Vector2", X = value.X, Y = value.Y }
	elseif kind == "Vector2int16" then
		return { __type = "Vector2int16", X = value.X, Y = value.Y }
	elseif kind == "Vector3int16" then
		return { __type = "Vector3int16", X = value.X, Y = value.Y, Z = value.Z }
	elseif kind == "CFrame" then
		return {
			__type = "CFrame",
			Components = { value:GetComponents() },
			Position = { X = value.Position.X, Y = value.Position.Y, Z = value.Position.Z },
			LookVector = {
				X = value.LookVector.X,
				Y = value.LookVector.Y,
				Z = value.LookVector.Z,
			},
		}
	elseif kind == "Color3" then
		return { __type = "Color3", R = value.R, G = value.G, B = value.B }
	elseif kind == "Color3uint8" then
		return { __type = "Color3uint8", R = value.R, G = value.G, B = value.B }
	elseif kind == "UDim" then
		return { __type = "UDim", Scale = value.Scale, Offset = value.Offset }
	elseif kind == "UDim2" then
		return {
			__type = "UDim2",
			XScale = value.X.Scale,
			XOffset = value.X.Offset,
			YScale = value.Y.Scale,
			YOffset = value.Y.Offset,
		}
	elseif kind == "NumberRange" then
		return { __type = "NumberRange", Min = value.Min, Max = value.Max }
	elseif kind == "NumberSequence" then
		return EncodeNumberSequence(value)
	elseif kind == "ColorSequence" then
		return EncodeColorSequence(value)
	elseif kind == "Rect" then
		return {
			__type = "Rect",
			Min = { X = value.Min.X, Y = value.Min.Y },
			Max = { X = value.Max.X, Y = value.Max.Y },
		}
	elseif kind == "Ray" then
		return {
			__type = "Ray",
			Origin = { X = value.Origin.X, Y = value.Origin.Y, Z = value.Origin.Z },
			Direction = {
				X = value.Direction.X,
				Y = value.Direction.Y,
				Z = value.Direction.Z,
			},
		}
	elseif kind == "BrickColor" then
		return { __type = "BrickColor", Name = value.Name, Number = value.Number }
	elseif kind == "buffer" or kind == "Buffer" then
		return EncodeBuffer(value)
	elseif kind == "function" then
		return { __type = "function", Name = FunctionLabel(value) }
	elseif kind == "thread" then
		return { __type = "thread" }
	elseif kind == "userdata" then
		return { __type = "userdata", Text = tostring(value) }
	end

	return { __type = "Datatype", ClassName = kind, Text = tostring(value) }
end

--[[ EncodeTable and EncodeValue call each other, so both are declared up front.
	Written as plain `local function` they would each resolve the other as a
	global nil at call time. ]]
local EncodeValue: (any, State, number) -> any
local EncodeTable: (any, State, number) -> any

EncodeTable = function(source: any, state: State, depth: number): any
	if state.seen[source] then return Truncated("cycle") end
	if depth >= state.MaxDepth then return Truncated("max-depth") end

	state.seen[source] = true

	local out: { [string]: any } = {}

	-- Frozen config tables get a metatable from table.freeze. That is not the
	-- "this object is live and has methods" signal we care about, so ignore it.
	local meta = if table.isfrozen(source) then nil else getmetatable(source)
	if meta ~= nil then out.__hasMetatable = true end

	-- Sorted so two identical calls produce two identical payloads.
	local keys = {}
	for key in pairs(source) do
		if #keys >= MAX_KEYS then
			out.__truncated = "key-budget"
			break
		end
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)

	for _, key in keys do
		local child = source[key]
		if child ~= nil then out[tostring(key)] = EncodeValue(child, state, depth + 1) end
	end

	state.seen[source] = nil

	return out
end

EncodeValue = function(value: any, state: State, depth: number): any
	state.nodes += 1
	if state.nodes > state.MaxNodes then return Truncated("node-budget") end

	local kind = typeof(value)

	if kind == "nil" or kind == "boolean" then
		return value
	elseif kind == "number" then
		return EncodeNumber(value)
	elseif kind == "string" then
		return EncodeString(value)
	elseif kind == "table" then
		return EncodeTable(value, state, depth)
	elseif kind == "Instance" then
		return EncodeInstance(value)
	end

	return EncodeDatatype(value, kind)
end

--- Converts any value into tagged, JSON-serializable plain data.
---
--- Budgets are per call, not per response. A single blanket Encode over a big
--- structure lets whichever branch comes first consume the whole budget and
--- leaves later branches as `Truncated` stubs. Encode each part on its own
--- instead, so a heavy field cannot starve a method list.
---
--- `__hasMetatable = true` marks a table that had a live metatable attached.
--- That flag is the honest signal that the object you are looking at is a
--- snapshot, not something you can hold on to.
function Codec.Encode(value: any, options: Options?): any
	local state: State = {
		nodes = 0,
		seen = {},
		MaxDepth = options and options.MaxDepth or MAX_DEPTH,
		MaxNodes = options and options.MaxNodes or MAX_NODES,
	}
	return EncodeValue(value, state, 0)
end

--- Reshapes an array so it survives the BindableEvent round trip and stays
--- self-describing. Items ends up with string keys ("1", "2", ...) because that
--- is what the transport does to it anyway; Count means an agent never has to
--- count them by hand.
function Codec.List(values: { any }): { [string]: any }
	return { Count = #values, Items = values }
end

--- Shared budgets so the tuning lives in one place.
---
--- A game object is a graph, not a record: one component holds three services,
--- which hold caches, which hold cleaners. There is no depth at which that reads
--- well, so the honest answer is to go shallow and say so.
Codec.Budgets = {
	-- Values an agent reads field by field.
	Wide = { MaxDepth = 5, MaxNodes = 300 },
	-- A whole live object: fields, specs, parameters.
	Default = { MaxDepth = 3, MaxNodes = 150 },
	-- A list of entries, each a shallow record.
	Shallow = { MaxDepth = 2, MaxNodes = 200 },
	-- One level: datatypes and scalars only.
	Flat = { MaxDepth = 1, MaxNodes = 200 },
}

local function Num(record: { [string]: any }, key: string, fallback: number): number
	local value = record[key]
	if type(value) == "number" then return value end
	return fallback
end

local Decoders: { [string]: (record: { [string]: any }) -> any } = {
	-- Resolves a GetFullName() path back into a live Instance so an agent can
	-- feed a result straight back into the next call. Instance names containing
	-- a dot will not resolve; that is the one documented limitation.
	Instance = function(record)
		local path = record.Path
		if type(path) ~= "string" or #path == 0 then return nil end

		local head, tail = path:match("^([^.]+)%.(.*)$")
		if not head then return game:FindFirstChild(path) end

		local root: Instance? = nil
		local served = pcall(function()
			root = game:GetService(head)
		end)
		if not served or not root then root = game:FindFirstChild(head) end
		if not root then return nil end

		local current: Instance = root
		for segment in tail:gmatch("[^.]+") do
			local found = current:FindFirstChild(segment)
			if not found then return nil end
			current = found
		end

		return current
	end,

	Vector3 = function(record)
		return Vector3.new(Num(record, "X", 0), Num(record, "Y", 0), Num(record, "Z", 0))
	end,
	Vector2 = function(record)
		return Vector2.new(Num(record, "X", 0), Num(record, "Y", 0))
	end,
	Vector2int16 = function(record)
		return Vector2int16.new(Num(record, "X", 0), Num(record, "Y", 0))
	end,
	Vector3int16 = function(record)
		return Vector3int16.new(Num(record, "X", 0), Num(record, "Y", 0), Num(record, "Z", 0))
	end,
	Color3 = function(record)
		return Color3.new(Num(record, "R", 0), Num(record, "G", 0), Num(record, "B", 0))
	end,
	Color3uint8 = function(record)
		return Color3.fromRGB(Num(record, "R", 0), Num(record, "G", 0), Num(record, "B", 0))
	end,
	UDim = function(record)
		return UDim.new(Num(record, "Scale", 0), Num(record, "Offset", 0))
	end,
	UDim2 = function(record)
		return UDim2.new(
			Num(record, "XScale", 0),
			Num(record, "XOffset", 0),
			Num(record, "YScale", 0),
			Num(record, "YOffset", 0)
		)
	end,
	NumberRange = function(record)
		return NumberRange.new(Num(record, "Min", 0), Num(record, "Max", 0))
	end,
	Rect = function(record)
		local min, max = record.Min, record.Max
		return Rect.new(
			if typeof(min) == "table" then Num(min, "X", 0) else 0,
			if typeof(min) == "table" then Num(min, "Y", 0) else 0,
			if typeof(max) == "table" then Num(max, "X", 0) else 0,
			if typeof(max) == "table" then Num(max, "Y", 0) else 0
		)
	end,
	Ray = function(record)
		local origin, direction = record.Origin, record.Direction
		return Ray.new(
			if typeof(origin) == "table"
				then Vector3.new(Num(origin, "X", 0), Num(origin, "Y", 0), Num(origin, "Z", 0))
				else Vector3.zero,
			if typeof(direction) == "table"
				then Vector3.new(
					Num(direction, "X", 0),
					Num(direction, "Y", 0),
					Num(direction, "Z", 0)
				)
				else Vector3.zero
		)
	end,
	CFrame = function(record)
		local components = record.Components
		if typeof(components) ~= "table" then return CFrame.identity end
		local built = {}
		local count = 0
		for _, component in components do
			count += 1
			if count > 12 then break end
			built[count] = if type(component) == "number" then component else 0
		end
		return CFrame.fromComponents(built)
	end,
	-- EnumType arrives as the plain type name ("KeyCode"), so it has to be
	-- looked back up through the global Enum registry.
	Enum = function(record)
		local enumType = record.EnumType
		local name = record.Name
		if type(enumType) ~= "string" or type(name) ~= "string" then return nil end

		local ok, resolved = pcall(function()
			return Enum[enumType][name]
		end)
		if ok then return resolved end

		return nil
	end,
}

--- Turns tagged records back into real Roblox datatypes.
--- Raw values (numbers, strings, live Instances an agent grabbed itself) pass
--- straight through untouched.
function Codec.Decode(value: any): any
	if typeof(value) ~= "table" then return value end

	local decoder = Decoders[value.__type :: string]
	if decoder then
		local ok, decoded = pcall(decoder, value)
		if ok then return decoded end
		return value
	end

	local out: { [string]: any } = {}
	for key, child in value do
		out[key] = Codec.Decode(child)
	end
	return out
end

--- BindableEvent hands arrays over with string indices. Normalises a value back
--- into a dense array so `args[1]` and `args["1"]` mean the same thing.
function Codec.ToArray(source: any): { [integer]: any }
	local out: { [integer]: any } = {}
	if typeof(source) ~= "table" then return out end

	local highest = 0
	for key in source do
		local index = tonumber(key)
		if index and index >= 1 and index == math.floor(index) and index > highest then
			highest = index
		end
	end

	for index = 1, highest do
		out[index] = source[tostring(index)] or source[index]
	end

	return out
end

--- Normalises an argument payload: tagged datatypes become real ones, and every
--- array-shaped field is repaired after the BindableEvent stringified its keys.
function Codec.DecodeArgs(source: any): { [string]: any }
	local out: { [string]: any } = {}
	if typeof(source) ~= "table" then return out end

	for key, value in source do
		local name = tostring(key)

		if name == "Args" or name == "Path" or name == "Properties" or name == "Filters" then
			out[name] = Codec.ToArray(value)
		else
			out[name] = Codec.Decode(value)
		end
	end

	return out
end

return Codec
