--!strict
--!native
--!optimize 2

--[[
	Proxy — a reactive wrapper around a replicated table.

	The proxy deep-copies its source on construction, applies batches of patch
	instructions, and notifies subscribers. Subscriptions are indexed in three
	buckets so that a patch costs one lookup plus the depth of the path:

	  exact       one instruction at exactly one path    O(1)
	  anyChange   every instruction at or under a path   O(depth)
	  pattern     paths containing `*` or `**`           O(number of patterns)

	`AnyChange` watches a subtree: a listener at `{"Skills"}` hears
	`SetDictionary {"Skills"}` as well as anything deeper. The opposite direction
	is deliberately not covered — replacing a parent with `ChangeValue` does not
	notify subscriptions below it, so a subscriber that cares about wholesale
	replacement watches the parent itself.
]]

-- TYPES

--- A path is either an array of segments or a `/`-separated string.
export type Path = string | { string }

--- Every real patch instruction. `AnyChange` is missing on purpose: it is a
--- subscription kind, not something that can be applied to the data.
export type InstructionName =
	"ChangeValue"
	| "InsertArray"
	| "RemoveArray"
	| "SetDictionary"
	| "RemoveDictionary"
	| "Clear"

export type Subscription = InstructionName | "AnyChange"

--- One entry in a `Patch` batch. `Args` is optional so that a caller can spell
--- the no-argument instructions without `Args = {}`.
export type Instruction = {
	Name: InstructionName,
	Path: Path,
	Args: { any }?,
}

--- Function returned by `Subscribe` to remove the listener.
export type CleanupFunction = () -> ()

--- Internal subscription. `Key` is `Path` already normalized into a hash key.
export type Listener = {
	Instruction: Subscription,
	Path: { string },
	Key: string,
	Callback: (...any) -> (),
}

--- What an instruction reports about itself. A handler returns `nil` when the
--- instruction changed nothing, which is what keeps no-ops out of `OnPatch`.
type InstructionResult = {
	Values: { any },
	Touched: { string },
	OldValue: any,
	NewValue: any,
}

type ListenerIndex = {
	exact: { [InstructionName]: { [string]: { Listener } } },
	anyChange: { [string]: { Listener } },
	patterns: { Listener },
}

type ProxyMethods<T> = {
	Patch: (self: ProxyTab<T>, instructions: { Instruction }) -> (),
	Subscribe: (
		self: ProxyTab<T>,
		instruction: Subscription,
		path: Path,
		callback: (...any) -> ()
	) -> CleanupFunction,
	OnPatch: (self: ProxyTab<T>, callback: (instructions: { Instruction }) -> ()) -> (),
}

type ProxyData<T> = {
	__source: T,
	__patchHandler: ((instructions: { Instruction }) -> ())?,
	__listeners: ListenerIndex,
}

--- Proxy table type. Calling it returns the underlying source table directly.
--- The call signature has to come first: the analyzer only keeps the callable
--- behaviour of an intersection when the function type leads it.
export type ProxyTab<T> = (() -> T) & ProxyData<T> & ProxyMethods<T>

-- UTILS

local function DeepCopy<T>(source: T): T
	local copy: any = {}

	for key, value in source :: any do
		copy[key] = if type(value) == "table" then DeepCopy(value) else value
	end

	return copy
end

--- Splits a `/`-separated path and drops empty segments, so `"/A/B"` behaves
--- like `"A/B"`. `string.split` would keep the leading empty one.
local function NormalizePath(path: Path): { string }
	local segments: { string } = {}

	if type(path) == "string" then
		for segment in path:gmatch("[^/]+") do
			table.insert(segments, segment)
		end

		return segments
	end

	for _, segment in path do
		table.insert(segments, tostring(segment))
	end

	return segments
end

--- Escapes the separator so that `{"A", "B"}` and `{"AB"}` cannot collide.
local function EscapeSegment(segment: string): string
	local escaped = segment:gsub("%%", "%%25")

	return (escaped:gsub("/", "%%2F"))
end

--- Lua hashes strings for table lookups already, so this is the only hash the
--- index needs: a second, hand-rolled one would just add work to every patch.
local function GetPathKey(path: { string }): string
	local parts: { string } = {}

	for _, segment in path do
		table.insert(parts, EscapeSegment(segment))
	end

	return table.concat(parts, "/")
end

local function HasPattern(path: { string }): boolean
	for _, segment in path do
		if segment == "*" or segment == "**" then return true end
	end

	return false
end

--- Resolves one segment against a table. Paths travel as strings — the `Patch`
--- packet schema is `array(string)` — while arrays are indexed by numbers, so
--- both spellings have to work. `~= nil` rather than `or` keeps a stored `false`.
local function GetKey(t: any, segment: string): any
	if t[segment] ~= nil then return segment end

	local index = tonumber(segment)

	if index ~= nil and t[index] ~= nil then return index end

	--- A key that does not exist yet is written as a string: instruction paths
	--- name dictionary fields, and arrays are changed through Insert/Remove.
	return segment
end

local function GetValueByPath(t: any, path: { string }): any
	for _, segment in path do
		if type(t) ~= "table" then return nil end

		local value = t[GetKey(t, segment)]

		if value == nil then return nil end

		t = value
	end

	return t
end

--- Writes the leaf of a path. Intermediate tables have to exist: silently
--- creating them would turn a typo in a path into data that looks meaningful.
local function SetValueByPath(t: any, path: { string }, value: any): boolean
	if #path == 0 then return false end

	local parent = t

	for index = 1, #path - 1 do
		local nextParent = GetValueByPath(parent, { path[index] })

		if nextParent == nil then return false end

		parent = nextParent
	end

	if type(parent) ~= "table" then return false end

	parent[GetKey(parent, path[#path])] = value

	return true
end

--- Path of the leaf an instruction actually touched.
local function Touch(path: { string }, key: string): { string }
	local touched = table.clone(path)

	table.insert(touched, key)

	return touched
end

--- `*` matches exactly one segment, `**` one or more. With `allowPrefix` the
--- pattern only has to match the head of the path, which is how `AnyChange`
--- hears changes below the subscribed path.
local function MatchPattern(pattern: { string }, path: { string }, allowPrefix: boolean): boolean
	local function walk(patternIndex: number, pathIndex: number): boolean
		if patternIndex > #pattern then return allowPrefix or pathIndex > #path end

		local segment = pattern[patternIndex]

		if segment == "**" then
			-- At the end it swallows the rest; otherwise the tail of the pattern
			-- has to fit after some number of consumed segments.
			if patternIndex == #pattern then return pathIndex <= #path end

			for nextIndex = pathIndex + 1, #path + 1 do
				if walk(patternIndex + 1, nextIndex) then return true end
			end

			return false
		end

		if pathIndex > #path then return false end
		if segment ~= "*" and segment ~= path[pathIndex] then return false end

		return walk(patternIndex + 1, pathIndex + 1)
	end

	return walk(1, 1)
end

-- PATCH INSTRUCTIONS

--- Every handler returns `nil` when nothing changed, so an equal value or a
--- missing target never reaches a listener and never reaches `OnPatch`.

local function ChangeValue(source: any, path: { string }, value: any): InstructionResult?
	local oldValue = GetValueByPath(source, path)

	if oldValue == value then return nil end
	if not SetValueByPath(source, path, value) then return nil end

	return {
		Values = { value, oldValue },
		Touched = path,
		OldValue = oldValue,
		NewValue = value,
	}
end

local function InsertArray(source: any, path: { string }, value: any): InstructionResult?
	local target = GetValueByPath(source, path)

	if type(target) ~= "table" then return nil end

	local index = #target + 1
	target[index] = value

	return {
		Values = { value, index },
		Touched = Touch(path, tostring(index)),
		OldValue = nil,
		NewValue = value,
	}
end

local function RemoveArray(source: any, path: { string }, index: any): InstructionResult?
	local target = GetValueByPath(source, path)
	local position = tonumber(index)

	if type(target) ~= "table" or position == nil then return nil end

	local oldValue = target[position]

	if oldValue == nil then return nil end

	table.remove(target, position)

	return {
		Values = { position, oldValue },
		Touched = Touch(path, tostring(position)),
		OldValue = oldValue,
		NewValue = nil,
	}
end

local function SetDictionary(
	source: any,
	path: { string },
	key: any,
	value: any
): InstructionResult?
	local target = GetValueByPath(source, path)

	if type(target) ~= "table" then return nil end

	local dictionaryKey = tostring(key)
	local oldValue = target[dictionaryKey]

	if oldValue == value then return nil end

	target[dictionaryKey] = value

	return {
		Values = { dictionaryKey, value, oldValue },
		Touched = Touch(path, dictionaryKey),
		OldValue = oldValue,
		NewValue = value,
	}
end

local function RemoveDictionary(source: any, path: { string }, key: any): InstructionResult?
	local target = GetValueByPath(source, path)

	if type(target) ~= "table" then return nil end

	local dictionaryKey = tostring(key)
	local oldValue = target[dictionaryKey]

	if oldValue == nil then return nil end

	target[dictionaryKey] = nil

	return {
		Values = { dictionaryKey, oldValue },
		Touched = Touch(path, dictionaryKey),
		OldValue = oldValue,
		NewValue = nil,
	}
end

--- Empties a table by replacing it, not by iterating it: the old reference then
--- stays readable for listeners, and a patch never mutates the table a caller
--- already holds. A primitive is reset to `nil`.
local function Clear(source: any, path: { string }): InstructionResult?
	local oldValue = GetValueByPath(source, path)

	if oldValue == nil then return nil end

	local newValue = if type(oldValue) == "table" then {} else nil

	if not SetValueByPath(source, path, newValue) then return nil end

	return {
		Values = { oldValue },
		Touched = path,
		OldValue = oldValue,
		NewValue = newValue,
	}
end

const VALID_NAMES: { [string]: boolean } = {
	ChangeValue = true,
	InsertArray = true,
	RemoveArray = true,
	SetDictionary = true,
	RemoveDictionary = true,
	Clear = true,
}

local function NormalizeArgs(args: { any }?): { any }
	if type(args) == "table" then return args end
	if args == nil then return {} end

	return { args }
end

local function ApplyInstruction(
	source: any,
	name: InstructionName,
	path: { string },
	args: { any }
): InstructionResult?
	if name == "ChangeValue" then return ChangeValue(source, path, args[1]) end
	if name == "InsertArray" then return InsertArray(source, path, args[1]) end
	if name == "RemoveArray" then return RemoveArray(source, path, args[1]) end
	if name == "SetDictionary" then return SetDictionary(source, path, args[1], args[2]) end
	if name == "RemoveDictionary" then return RemoveDictionary(source, path, args[1]) end
	if name == "Clear" then return Clear(source, path) end

	return nil
end

-- LISTENERS

--- A listener that throws must not take the rest of the batch down with it:
--- losing the `OnPatch` call would desynchronise every client. The failure is
--- reported and the batch continues.
local function Fire(callback: (...any) -> (), ...: any)
	-- `pcall` is typed as returning the callback's own results, and a listener
	-- returns none: packing it keeps the error message as the second value.
	local packed = table.pack(pcall(callback, ...))

	if not packed[1] then warn(`Proxy: subscription callback failed: {packed[2]}`) end
end

local function RemoveListener(index: ListenerIndex, listener: Listener)
	local bucket: { Listener }?
	local owner: { [string]: { Listener } }?

	if HasPattern(listener.Path) then
		bucket = index.patterns
	elseif listener.Instruction == "AnyChange" then
		bucket = index.anyChange[listener.Key]
		owner = index.anyChange
	else
		local byInstruction = index.exact[listener.Instruction :: InstructionName]
		bucket = if byInstruction then byInstruction[listener.Key] else nil
		owner = byInstruction
	end

	if not bucket then return end

	local position = table.find(bucket, listener)

	if position then table.remove(bucket, position) end

	-- Ids come and go, so a path nobody listens to is dropped instead of leaving
	-- one small table behind per skill that was ever replicated.
	if owner and #bucket == 0 then owner[listener.Key] = nil end
end

-- CLASS

local Proxy = {}

--- Applies a batch of patch instructions to the proxied table.
--- Triggers matching path listeners and the global OnPatch handler.
--- @param self ProxyTab<T>
--- @param instructions {Instruction}
function Proxy.Patch<T>(self: ProxyTab<T>, instructions: { Instruction })
	if #instructions == 0 then return end

	local source: any = self.__source
	local index = self.__listeners
	local patched: { Instruction } = {}

	for _, instruction in instructions do
		-- The annotation is load-bearing: an unannotated local widens the union of
		-- singletons to `string`, and every lookup below then fails to type-check.
		local name: InstructionName = instruction.Name

		if not VALID_NAMES[name] then
			warn(`Proxy: unknown patch instruction "{tostring(name)}" was skipped`)
			continue
		end

		local path = NormalizePath(instruction.Path)

		if #path == 0 then
			warn("Proxy: patch instruction with an empty path was skipped")
			continue
		end

		local args = NormalizeArgs(instruction.Args)
		local result = ApplyInstruction(source, name, path, args)

		if not result then continue end

		-- The forwarded copy carries a normalized path: the packet schema is
		-- `array(string)`, and the caller's tables stay untouched.
		table.insert(patched, { Name = name, Path = path, Args = args })

		local byInstruction = index.exact[name]
		local exact = if byInstruction then byInstruction[GetPathKey(path)] else nil

		if exact then
			for _, listener in exact do
				Fire(listener.Callback, table.unpack(result.Values))
			end
		end

		-- `AnyChange` at the touched leaf and at every path above it, so a single
		-- `SetDictionary {"Skills"}` reaches listeners on `{"Skills", id}` too.
		local prefix = ""

		for depth, segment in result.Touched do
			local escaped = EscapeSegment(segment)

			prefix = if depth == 1 then escaped else `{prefix}/{escaped}`

			local bucket = index.anyChange[prefix]

			if not bucket then continue end

			for _, listener in bucket do
				Fire(listener.Callback, result.NewValue, result.OldValue, instruction)
			end
		end

		-- Patterns are rare, so scanning the list beats maintaining a trie.
		for _, listener in index.patterns do
			local matches: boolean

			if listener.Instruction == "AnyChange" then
				matches = MatchPattern(listener.Path, result.Touched, true)
			else
				matches = listener.Instruction == name and MatchPattern(listener.Path, path, false)
			end

			if not matches then continue end

			if listener.Instruction == "AnyChange" then
				Fire(listener.Callback, result.NewValue, result.OldValue, instruction)
			else
				Fire(listener.Callback, table.unpack(result.Values))
			end
		end
	end

	local handler = self.__patchHandler

	if handler and #patched > 0 then
		local packed = table.pack(pcall(handler, patched))

		if not packed[1] then warn(`Proxy: OnPatch handler failed: {packed[2]}`) end
	end
end

--- Subscribes to an instruction at a path, or to every change at and below it
--- with `"AnyChange"`. Returns a cleanup function to unsubscribe.
--- @param self ProxyTab<T>
--- @param instruction Subscription
--- @param path Path
--- @param callback (...any) -> ()
--- @return CleanupFunction
function Proxy.Subscribe<T>(
	self: ProxyTab<T>,
	instruction: Subscription,
	path: Path,
	callback: (...any) -> ()
): CleanupFunction
	local segments = NormalizePath(path)

	if #segments == 0 then
		warn("Proxy: Subscribe requires a non-empty path")
		return function() end
	end

	local listener: Listener = {
		Instruction = instruction,
		Path = segments,
		Key = GetPathKey(segments),
		Callback = callback,
	}

	local index = self.__listeners
	local bucket: { Listener }

	if HasPattern(segments) then
		bucket = index.patterns
	elseif instruction == "AnyChange" then
		local existing = index.anyChange[listener.Key]

		if existing then
			bucket = existing
		else
			bucket = {}
			index.anyChange[listener.Key] = bucket
		end
	else
		local name: InstructionName = instruction :: InstructionName
		local byInstruction = index.exact[name]

		if not byInstruction then
			byInstruction = {}
			index.exact[name] = byInstruction
		end

		local existing = byInstruction[listener.Key]

		if existing then
			bucket = existing
		else
			bucket = {}
			byInstruction[listener.Key] = bucket
		end
	end

	table.insert(bucket, listener)

	return function()
		RemoveListener(index, listener)
	end
end

--- Registers a global callback invoked after successful patches.
--- @param self ProxyTab<T>
--- @param callback (instructions: {Instruction}) -> ()
function Proxy.OnPatch<T>(self: ProxyTab<T>, callback: (instructions: { Instruction }) -> ())
	self.__patchHandler = callback
end

-- CONSTRUCTOR

--- Creates a new proxy table that wraps the source data.
--- The proxy can be called as a function to retrieve the source table directly.
--- @param t T Source table to proxy
--- @return ProxyTab<T>
local function New<T>(t: T): ProxyTab<T>
	assert(type(t) == "table", "Proxy only accepts a table")

	local proxy = setmetatable({
		__source = DeepCopy(t),
		__listeners = {
			exact = {},
			anyChange = {},
			patterns = {},
		},
	}, {
		__call = function(self: any)
			return self.__source
		end,
		__index = Proxy,
	}) :: any

	return proxy :: ProxyTab<T>
end

return New
