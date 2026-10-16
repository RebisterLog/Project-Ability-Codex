--!strict
--- Stand-in for the Roblox environment so skills can run outside Studio.
---
--- A skill is an ordinary module with top-level `game:GetService(...)`,
--- `require`, `task` and `Vector3`. Lune knows none of them and the Roblox
--- engine is out of reach, so the environment is assembled here and injected
--- into the chunk through the prelude (see `Loader`).
---
--- Data types are the genuine article: `@lune/roblox` provides `Instance`,
--- `Vector3`, `CFrame`, `Color3`, `Enum` with working math. Hand-rolling
--- `CFrame` is pointless when a realtime Roblox implementation sits right there.
---
--- Time and `task`, on the other hand, are ours and deterministic: the real
--- clock would make a test run irreproducible, and `task.delay(1.5, ...)` in
--- combo skills has to fire on schedule, not whenever it feels like it.

local roblox = require("@lune/roblox")

local Roblox = {}

--- The data types skills get to see.
---
--- Casting to `any` is not laziness but a consequence of the typedefs: in
--- `~/.lune/.typedefs/<version>/roblox.luau` only `Instance` is typed, the
--- remaining classes are marked `TODO` and are simply absent from the table as
--- far as the analyzer is concerned. In reality they are there and they work.
local datatypes = roblox :: any

Roblox.Datatypes = {
	Instance = datatypes.Instance,
	Vector3 = datatypes.Vector3,
	Vector2 = datatypes.Vector2,
	CFrame = datatypes.CFrame,
	Color3 = datatypes.Color3,
	BrickColor = datatypes.BrickColor,
	Enum = datatypes.Enum,
	UDim2 = datatypes.UDim2,
	UDim = datatypes.UDim,
	NumberSequence = datatypes.NumberSequence,
	NumberRange = datatypes.NumberRange,
	ColorSequence = datatypes.ColorSequence,
	Region3 = datatypes.Region3,
	Ray = datatypes.Ray,
	Rect = datatypes.Rect,
	Axes = datatypes.Axes,
	Faces = datatypes.Faces,
	PhysicalProperties = datatypes.PhysicalProperties,
	UniqueId = datatypes.UniqueId,

	-- `TweenInfo` is a plain value object and `@lune/roblox` does not ship it,
	-- so it is written by hand. It carries no behaviour: `TweenService:Create`
	-- never looks inside it, it only passes it back on `Cancel`.
	TweenInfo = {
		new = function(time: number, easingStyle: any, easingDirection: any, repeatCount: number?)
			return {
				Time = time,
				EasingStyle = easingStyle,
				EasingDirection = easingDirection,
				RepeatCount = repeatCount or 0,
			}
		end,
	},
}

--- Virtual clock. `os.clock()` in the skills and in the combat classes means
--- "time since the start", so the counter starts at zero and only moves when
--- the test asks it to.
function Roblox.newClock(): any
	local clock = { time = 0 }

	--- Moves time forward and runs everything that was due by that moment:
	--- without this, `task.delay` would be impossible to check.
	function clock.advance(seconds: number)
		clock.time += seconds
		clock.flush()
	end

	function clock.flush()
		while true do
			local due = table.remove(clock.due or {}, 1)

			if not due then break end
			if due.at <= clock.time then due.fn() end
		end
	end

	clock.due = {}

	function clock.schedule(at: number, fn: () -> ())
		table.insert(clock.due, { at = at, fn = fn })
	end

	clock.os = {
		clock = function()
			return clock.time
		end,
		time = function()
			return math.floor(clock.time)
		end,
		date = function()
			return 0
		end,
	}

	return clock
end

--- `task` with a deterministic schedule. A regular `task.spawn` runs the
--- function immediately: there is no parallelism in a test, so deferring here
--- would only mean a race.
function Roblox.newTask(clock: any): any
	local counters = { id = 0 }
	local pending: { [string]: boolean } = {}

	return {
		spawn = function(fn: any, ...)
			counters.id += 1
			local thread = counters.id

			pending[tostring(thread)] = true

			local results = table.pack(pcall(fn, ...))

			pending[tostring(thread)] = nil

			if not results[1] then error(results[2] :: string, 0) end

			return thread
		end,

		delay = function(seconds: number, fn: any, ...)
			counters.id += 1

			-- The arguments are packed: inside the nested function `...` is no
			-- longer visible, and the deferred call would silently drop them.
			local args = table.pack(...)

			local thread = counters.id
			local token = tostring(thread)

			pending[token] = true
			clock.schedule(clock.time + seconds, function()
				pending[token] = nil
				fn(table.unpack(args, 1, args.n))
			end)

			return thread
		end,

		wait = function(seconds: number?)
			local start = clock.time

			if seconds and seconds > 0 then clock.advance(seconds) end

			return clock.time - start
		end,

		cancel = function(thread: any)
			if thread ~= nil then pending[tostring(thread)] = nil end
		end,

		defer = function(fn: () -> ())
			clock.schedule(clock.time, fn)
		end,
	}
end

--- Path container shaped like an instance tree:
--- `ReplicatedStorage.shared.packages.Crane`. Every node remembers its own
--- path in `__path`, which is how the `require` shim finds the module it wants.
---
--- Unknown paths are created on the fly: a skill may require anything at all,
--- and a missing stub must not take the run down.
local function pathNode(path: string?): any
	local node = {}

	rawset(node, "__path", path)

	return setmetatable(node, {
		__index = function(self, key)
			local child = pathNode(if path then `{path}.{key}` else tostring(key))
			rawset(self, key, child)

			return child
		end,
		__tostring = function()
			return path or "<root>"
		end,
	})
end

--- The services skills see. `ReplicatedStorage` and `ServerScriptService`
--- hand back path trees, the rest are stubs carrying exactly the methods that
--- get called (`Players:GetPlayers`, `RunService.Heartbeat:Connect`).
function Roblox.services(): any
	const Players = {
		GetPlayers = function()
			return { { Name = "Tester", UserId = 1 } }
		end,
		GetPlayerFromCharacter = function()
			return nil
		end,
		GetPlayerByCharacter = function()
			return nil
		end,
	}

	local Heartbeat = {
		Connect = function()
			return { Disconnect = function() end }
		end,
	}

	local ReplicatedStorage = pathNode("ReplicatedStorage")
	local ServerScriptService = pathNode("ServerScriptService")

	-- `assets` in skins is a tree of real Roblox instances, which do not exist
	-- here. A tree of our own is needed for two reasons: a real `Folder`
	-- throws when you touch a child that does not exist, and the skin config
	-- reads branches like `assets.Default.NonArmedSpecs` that need not be there
	-- at all in the game; and any path has to yield an object, not `nil`.
	local function assetTree(path: string): any
		local node = { __asset = path, __attributes = {} }

		return setmetatable(node, {
			__index = function(self, key)
				-- Assets are instances in the game, and skills read attributes off
				-- them, for example
				-- `CircularKickGroundHit:GetAttribute("Offset")`. The values live
				-- in the place file, which is not here, so unknown attributes read
				-- as nil rather than erroring.
				if key == "GetAttribute" then
					return function(_node, name)
						return (rawget(self, "__attributes") :: any)[name]
					end
				end

				if key == "SetAttribute" then
					return function(_node, name, value)
						(rawget(self, "__attributes") :: any)[name] = value
					end
				end

				-- `Clone` is not optional: the tree answers any key with a
				-- child, so without this `model:Clone()` would return a table
				-- and the call itself would fail with "attempt to call a table
				-- value" - a confusing message that points at the skill.
				if key == "Clone" then
					return function()
						return assetTree(path)
					end
				end

				if key == "Destroy" then
					return function() end
				end

				if key == "IsA" then
					return function()
						return false
					end
				end

				if key == "GetFullName" then
					return function()
						return path
					end
				end

				const child = assetTree(if path == "" then tostring(key) else `{path}/{key}`)
				rawset(self, key, child)

				return child
			end,
			__tostring = function()
				return path
			end,
		})
	end

	ReplicatedStorage.assets = assetTree("")

	return {
		Players = Players,
		ReplicatedStorage = ReplicatedStorage,
		ServerScriptService = ServerScriptService,
		TweenService = {
			Create = function(_self, _info, _goals)
				return { Play = function() end, Cancel = function() end }
			end,
		},
		RunService = {
			IsStudio = function()
				return true
			end,
			Heartbeat = Heartbeat,
			Stepped = Heartbeat,
		},

		-- Skills clean up after themselves by scheduling a deletion rather than
		-- holding the object. Nothing has to survive the test, so the item is
		-- simply dropped - but it has to be accepted, not reported as an
		-- unknown service.
		Debris = {
			AddItem = function(_self, _instance, _time) end,
			ClearItem = function(_self, _instance) end,
		},

		-- Both spellings exist in Roblox: `workspace` is a global, and
		-- `game:GetService("Workspace")` is accepted too - it is the form the
		-- Creator Hub documents in its own DataModel example. `DualPistols` uses
		-- the service form, so the fake has to answer to it.
		workspace = pathNode("workspace"),
		Workspace = pathNode("Workspace"),
	}
end

return Roblox
