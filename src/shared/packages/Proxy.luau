--!strict
--!native
--!optimize 2
-- UTILS

local function DeepCopy<T>(t: T): T
	local copy = {}

	for key, value in t :: { any } do
		if typeof(value) ~= "table" then
			copy[key] = value
			continue
		end

		copy[key] = DeepCopy(value)
	end

	return copy :: T
end

--- Traverses a nested table using a path array of keys.
--- @param t table The source table.
--- @param path {string} Array of keys representing the path.
--- @return any value The value at the specified path.
local function GetValueByPath(t: any, path: { string })
	for _, v in path do
		t = t[v] or t[tonumber(v)]
	end

	return t
end

--- Updates the leaf value at the specified path.
--- @param t table The source table.
--- @param path {string} Array of keys representing the path.
--- @param value any The value to set.
local function SetValueByPath(t: any, path: { string }, value: any)
	for i, v in path do
		if i == #path then
			t[v] = value
		else
			t = t[v] or t[tonumber(v)]
		end
	end
end

--- Converts a path array into a single string for fast equality comparison.
--- @param path {string} The path array.
--- @return string The joined path string.
local function GetPathAsString(path: { string })
	local pathString = ""

	for _, v in path do
		pathString = pathString .. v
	end

	return pathString
end

local function GetPathFromString(pathString: string)
	return pathString:split("/")
end

-- PATCH INSTRUCTIONS
local PatchInstructions = {

	--- Changes a primitive value at the given path. Only for simple value types (number, boolean, string).
	--- @param t table Target table
	--- @param path {string} Path to the value
	--- @param value any New value
	--- @return any newValue, any? oldValue
	["ChangeValue"] = function(t, path: { string }, value: any)
		if not path or #path == 0 then return end

		local oldValue = GetValueByPath(t, path)

		if oldValue == value then return end

		SetValueByPath(t, path, value)
		return value, oldValue
	end,

	--- Inserts a value into an array at the given path.
	--- @param t table Target table
	--- @param path {string} Path to the array
	--- @param value any Value to insert
	--- @return any newValue, number index
	["InsertArray"] = function(t, path: { string }, value: any)
		if not path or #path == 0 then return end

		table.insert(GetValueByPath(t, path), value)

		return value, #path
	end,

	--- Removes a value from an array at the given path by index.
	--- @param t table Target table
	--- @param path {string} Path to the array
	--- @param index number Index to remove
	--- @return number index, any? oldValue
	["RemoveArray"] = function(t, path: { string }, index: number)
		if not path or #path == 0 then return end
		if not GetValueByPath(t, path)[index] then return end

		local oldValue = GetValueByPath(t, path)[index]
		table.remove(GetValueByPath(t, path), index)

		return index, oldValue
	end,

	--- Sets or updates a key-value pair in a dictionary at the given path.
	--- @param t table Target table
	--- @param path {string} Path to the dictionary
	--- @param key string Dictionary key
	--- @param value any New value
	--- @return string key, any newValue, any? oldValue
	["SetDictionary"] = function(t, path: { string }, key: string, value: any)
		if not path or #path == 0 then return end

		local target = GetValueByPath(t, path)
		local oldValue = target[key]

		if oldValue == value then return end

		target[key] = value

		return key, value, oldValue
	end,

	--- Removes a key-value pair from a dictionary at the given path.
	--- @param t table Target table
	--- @param path {string} Path to the dictionary
	--- @param key string Key to remove
	--- @return string key, any? oldValue
	["RemoveDictionary"] = function(t, path: { string }, key: string)
		if not path or #path == 0 then return end
		if not GetValueByPath(t, path)[key] then return end

		local oldValue = GetValueByPath(t, path)[key]

		GetValueByPath(t, path)[key] = nil

		return key, oldValue
	end,

	["Clear"] = function(t, path: { string })
		if not path or #path == 0 then return end
		local oldValue = GetValueByPath(t, path)

		if typeof(oldValue) == "table" then
			SetValueByPath(t, path, {})
		else
			SetValueByPath(t, path, oldValue)
		end

		return oldValue
	end,

	["AnyChange"] = function(t, path: { string })
		if not path or #path == 0 then return end
		return GetValueByPath(t, path)
	end,
}

-- TYPES

--- Function returned by Subscribe to remove the listener.
--- @type CleanupFunction
export type CleanupFunction = () -> ()

--- Internal listener structure for path-specific callbacks.
--- @type Listener
export type Listener = {
	Instruction: string,
	Path: { string },
	Callback: (...any) -> (),
}

--- Instruction object passed to Patch.
--- @type Instruction
export type Instruction = {
	Name: keyof<typeof(PatchInstructions)>,
	Path: { string },
	Args: { any },
}

--- Public methods exposed on the proxy table.
--- @type ProxyMethods
type ProxyMethods<T> = {
	Patch: (self: ProxyTab<T>, instructions: { Instruction }) -> (),
	Subscribe: (
		self: ProxyTab<T>,
		instruction: keyof<typeof(PatchInstructions)>,
		path: { string },
		callback: (...any) -> ()
	) -> CleanupFunction,
	OnPatch: (self: ProxyTab<T>, callback: (patchedInstructions: { Instruction }) -> ()) -> (),
}

--- Internal proxy data structure combined with public methods.
--- @type ProxyData
type ProxyData<T> = {
	__source: T,
	__patchHandler: ((patchedInstructions: { Instruction }) -> ())?,
	__listeners: { Listener },
}

--- Proxy table type. Calling it returns the underlying source table directly.
--- @type ProxyTab
export type ProxyTab<T> = setmetatable<ProxyData<T> & ProxyMethods<T>, { __call: (self: any) -> T }>

-- CLASS
local Proxy = {}

--- Applies a batch of patch instructions to the proxied table.
--- Triggers matching path listeners and the global OnPatch handler.
--- @param self ProxyTab<T>
--- @param instructions {Instruction}
function Proxy.Patch<T>(self: ProxyTab<T>, instructions: { Instruction })
	if #instructions == 0 then return end
	local patchedInstructions = {}

	for _, instruction in instructions do
		if not PatchInstructions[instruction.Name] then
			warn("Invalid patch instruction Name:", instruction.Name)
			continue
		end

		instruction.Args = instruction.Args or {}
		local args = typeof(instruction.Args) ~= "table" and { instruction.Args }
			or instruction.Args
		local path = typeof(instruction.Path) == "table" and instruction.Path
			or typeof(instruction.Path) == "string" and GetPathFromString(instruction.Path)
		if not path or #path == 0 then
			warn("Invalid patch instruction Path:", instruction.Path)
			continue
		end
		-- table.pack safely captures variable return values from dynamic instruction calls
		local results =
			table.pack(PatchInstructions[instruction.Name](self(), path, table.unpack(args)))
		if results.n == 0 then continue end

		table.insert(patchedInstructions, instruction)

		for _, listener in self.__listeners :: { Listener } do
			if listener.Instruction ~= instruction.Name then continue end
			-- Stringified path comparison avoids O(n) table equality checks
			if GetPathAsString(listener.Path) ~= GetPathAsString(path) then continue end

			listener.Callback(table.unpack(results))
		end

		for _, listener in self.__listeners :: { Listener } do
			if
				listener.Instruction == "AnyChange"
				and GetPathAsString(path) == GetPathAsString(listener.Path)
			then
				listener.Callback(table.unpack(results))
			end
		end
	end

	if self.__patchHandler then self.__patchHandler(patchedInstructions) end
end

--- Subscribes to a specific patch instruction at a given path.
--- Returns a cleanup function to unsubscribe.
--- @param self ProxyTab<T>
--- @param instruction keyof<typeof(PatchInstructions)>
--- @param path {string}
--- @param callback (...any) -> ()
--- @return CleanupFunction
function Proxy.Subscribe<T>(
	self: ProxyTab<T>,
	instruction: keyof<typeof(PatchInstructions)>,
	path: { string },
	callback: (...any) -> ()
)
	local listener = {
		Instruction = instruction,
		Path = path,
		Callback = callback,
	} :: Listener

	table.insert(self.__listeners, listener)

	return function()
		local index = table.find(self.__listeners, listener)
		if index then table.remove(self.__listeners, index) end
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
local function New<T>(t: T)
	assert(type(t) == "table", "Proxy only accepts a table")

	local proxy = setmetatable({
		__source = DeepCopy(t),
		__listeners = {},
	}, {
		__call = function(self)
			return self.__source
		end,
		__index = Proxy,
	}) :: ProxyTab<T>

	return proxy
end

return New
