--!strict
--[[
╔══════════════════════════════════════════════════════════════════════════════╗
║                           B U T L E R   v2.0.1                               ║
║                    Next-Gen Roblox Memory Management                         ║
╚══════════════════════════════════════════════════════════════════════════════╝

  Inspired by: Maid (Quenty), Trove (Sleitnick), Janitor (howmanysmall)
  External patterns borrowed from:
    • Rust  — RAII / Drop trait / ScopeGuard  (deterministic scoped cleanup)
    • C++   — ScopeExit, unique_ptr ownership semantics
    • RxJS  — Subscription teardown, takeUntil, CompositeDisposable, finalize()
    • TC39  — Explicit Resource Management proposal (Symbol.dispose / using)
    • Go    — defer statement (run-at-scope-exit)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  WHAT IS BUTLER?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Butler is a lifecycle / memory management module. It tracks connections,
  instances, coroutines, promises, and arbitrary cleanup functions, then
  destroys them all at once when a system (a player, character, component)
  is done.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  COMPLETE API
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Butler.new()                                   → Butler
  Butler.setDebug(enabled)                       global debug toggle

  ── Core tracking ──────────────────────────────────────────────────────────
  butler:Add(obj, method?)                       → obj
  butler:AddChain(obj, method?)                  → butler  (fluent chaining)
  butler:Set(name, obj, method?)                 → obj     (named slot)
  butler:Remove(nameOrObj)
  butler:Has(name)                               → boolean
  butler:Count()                                 → number
  butler:IsAlive()                               → boolean

  ── Signals ────────────────────────────────────────────────────────────────
  butler:Connect(signal, fn)                     → RBXScriptConnection
  butler:Once(signal, fn)                        → RBXScriptConnection
  butler:Until(untilSig, listenSig, fn)          → RBXScriptConnection
  butler:ConnectMany({{signal,fn},...})          → {RBXScriptConnection}

  ── Constructing & Instances ───────────────────────────────────────────────
  butler:Construct(class, ...)                   → object
  butler:Clone(instance)                         → Instance
  butler:AddInstance(inst, parent?)              → Instance

  ── Async / Threads ────────────────────────────────────────────────────────
  butler:Task(fn)                                → thread
  butler:Delay(t, fn)                            → thread
  butler:Every(interval, fn)                     → thread

  ── Rust/C++ patterns ──────────────────────────────────────────────────────
  butler:Guard(value, cleanupFn)                 → value   (Drop/ScopeGuard)
  butler:Defer(fn)                               → butler  (SCOPE_EXIT/defer!)

  ── RxJS patterns ──────────────────────────────────────────────────────────
  butler:Batch({items})                          → butler  (CompositeDisposable)
  butler:OnClean(fn)                             → butler  (finalize() observer)
  butler:Wrap(object)                            → DisposableHandle

  ── Roblox QoL ─────────────────────────────────────────────────────────────
  butler:Tween(inst, info, goals)                → Tween   (tracked + played)
  butler:WaitFor(inst, childName, timeout?)      → Instance?

  ── Scoping & Linking ──────────────────────────────────────────────────────
  butler:Scope()                                 → Butler  (child)
  butler:LinkToInstance(inst, allowReAdd?)       → RBXScriptConnection

  ── Lifecycle ──────────────────────────────────────────────────────────────
  butler:Clean()                                 cleans tasks, stays alive
  butler:Destroy()                               cleans + invalidates
  butler:Snapshot()                              → {[key]:string} debug view

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
--]]

local TweenService = game:GetService("TweenService")

type TaskEntry = {
	object: any,
	method: string?,
	label: string?,
}

type SignalHandlerPair = { [number]: RBXScriptSignal | ((...any) -> ()) }
type FunctionConstructor<T> = (...any) -> T
type TableConstructor<T> = { new: (...any) -> T }
type Constructor<T> = FunctionConstructor<T> | TableConstructor<T>

export type DisposableHandle<T> = T & {
	Dispose: (self: DisposableHandle<T>) -> (),
}

-- ─── Module ──────────────────────────────────────────────────────────────────

local Butler = {}
Butler.__index = Butler

-- ─── Debug ───────────────────────────────────────────────────────────────────

local _debugEnabled = false

--[[
	Enable or disable debug logging globally.
	When enabled, Butler prints each task as it is cleaned, with timing.
]]
function Butler.setDebug(enabled: boolean)
	_debugEnabled = enabled
end

local function _log(...)
	if _debugEnabled then
		print("[Butler]", ...)
	end
end

local function _warn(msg: string)
	warn("[Butler] " .. msg)
end

-- ─── Internal cleanup ────────────────────────────────────────────────────────

--[[
	Execute the cleanup for a single tracked item.

	Cleanup priority order:
	  1. Custom method string   → call object:<method>()
	  2. function               → call it directly
	  3. RBXScriptConnection    → :Disconnect()
	  4. thread                 → task.cancel()          [Rust Drop for threads]
	  5. Instance               → :Destroy()
	  6. table with Tween API   → :Cancel() then :Destroy()
	  7. Promise-like           → :cancel() if Started/Running
	  8. table with Destroy     → :Destroy() / :destroy()
	  9. table with Disconnect  → :Disconnect() / :disconnect()

	All errors are caught and warned. A bad task never aborts the clean chain.
]]
local function _cleanItem(object: any, method: string?, label: string?): ()
	local t0 = _debugEnabled and os.clock() or 0

	local packed = table.pack(pcall(function()

		-- 1. Custom cleanup method specified by caller
		if method then
			local fn = (object :: any)[method]
			if type(fn) == "function" then
				fn(object)
			else
				_warn(("cleanupMethod '%s' not found on %s"):format(method, typeof(object)))
			end
			return
		end

		local t = typeof(object)

		-- 2. Plain function (Defer, closures, etc.)
		if t == "function" then
			object()

			-- 3. RBXScriptConnection
		elseif t == "RBXScriptConnection" then
			object:Disconnect()

			-- 4. Coroutine / thread — task.cancel() is Luau's Drop for threads
		elseif t == "thread" then
			local canceled = pcall(task.cancel, object)
			if not canceled then
				local statusOk, status = pcall(coroutine.status, object)
				if statusOk and status == "suspended" then
					pcall(coroutine.close, object)
				end
			end

			-- 5. Roblox Instance
		elseif t == "Instance" then
			object:Destroy()

			-- 6. Table — detect type by duck-typing
		elseif t == "table" then
			local function safeMember(key: string): any
				local readOk, value = pcall(function()
					return (object :: any)[key]
				end)
				if readOk then
					return value
				end
				return nil
			end

			local getStatus = safeMember("getStatus")
			local cancel = safeMember("cancel")
			local cancelUpper = safeMember("Cancel")
			local play = safeMember("Play")
			local destroyUpper = safeMember("Destroy")
			local destroyLower = safeMember("destroy")
			local disconnectUpper = safeMember("Disconnect")
			local disconnectLower = safeMember("disconnect")

			-- 6a. Promise (evaera / roblox-ts: has getStatus + cancel)
			if type(getStatus) == "function" and type(cancel) == "function" then
				local status = object:getStatus()
				if status == "Started" or status == "Running" then
					object:cancel()
				end

				-- 6b. Tween — cancel BEFORE destroy to stop the animation
			elseif type(cancelUpper) == "function" and type(play) == "function" then
				object:Cancel()
				if type(destroyUpper) == "function" then
					object:Destroy()
				end

				-- 6c. Standard OOP: Destroy / destroy
			elseif type(destroyUpper) == "function" then
				object:Destroy()
			elseif type(destroyLower) == "function" then
				object:destroy()

				-- 6d. Disconnectable
			elseif type(disconnectUpper) == "function" then
				object:Disconnect()
			elseif type(disconnectLower) == "function" then
				object:disconnect()

			else
				_warn("Table has no recognized cleanup method (Destroy/Disconnect/cancel)")
			end

		else
			_warn(("Unrecognized task type '%s'; skipping"):format(t))
		end
	end))
	local ok = packed[1] == true
	local err = packed[2]

	if _debugEnabled then
		local elapsed = (os.clock() - t0) * 1000
		_log(
			("  cleaned [%s] in %.3fms%s"):format(
				label or (method and (":" .. method) or typeof(object)),
				elapsed,
				ok and "" or (" !! ERROR: " .. tostring(err))
			)
		)
	elseif not ok then
		_warn(("Cleanup error: %s"):format(tostring(err)))
	end
end

-- ─── Constructor ─────────────────────────────────────────────────────────────

--[[
	Create a new Butler instance.
]]
function Butler.new()
	local self = setmetatable({
		_tasks     = {} :: { TaskEntry },
		_named     = {} :: { [string]: TaskEntry },
		_onClean   = {} :: { () -> () },
		_destroyed = false,
		_linked    = nil :: RBXScriptConnection?,
	}, Butler)
	return self
end

-- ─── Internal guards ─────────────────────────────────────────────────────────

local function _alive<T>(self: T & { _destroyed: boolean }, op: string)
	if self._destroyed then
		error(("[Butler] :%s() called on a destroyed Butler"):format(op), 3)
	end
end

local function _entry(object: any, method: string?, label: string?): TaskEntry
	return { object = object, method = method, label = label }
end

-- ─── Add / AddChain ──────────────────────────────────────────────────────────

--[[
	Add — track an object for cleanup. Returns the object.

	All of the following work:
	    butler:Add(connection)
	    butler:Add(part)
	    butler:Add(function() ... end)
	    butler:Add(tween, "Cancel")       -- custom method
	    butler:Add(thread)
]]
function Butler:Add<T>(object: T, method: string?, label: string?): T
	_alive(self, "Add")
	assert(object ~= nil, "[Butler] Cannot track nil")
	table.insert(self._tasks, _entry(object, method, label))
	_log("+ tracked:", label or typeof(object))
	return object
end

--[[
	AddChain — same as Add but returns self for builder-pattern chaining.

	    Butler.new()
	        :AddChain(conn1)
	        :AddChain(conn2)
	        :LinkToInstance(player)
]]
function Butler:AddChain<T>(object: T, method: string?, label: string?)
	self:Add(object, method, label)
	return self
end

-- ─── Named tasks: Set / Has / Remove ─────────────────────────────────────────

--[[
	Set — track an object under a named slot.
	If the slot is already occupied, the previous object is cleaned first.
	This is the fix for the most common Maid / Trove pain point:
	"I need to replace a connection but don't want to manually disconnect it."

	    butler:Set("damageConn", humanoid.HealthChanged:Connect(fn))
	    -- Later, on respawn:
	    butler:Set("damageConn", newHumanoid.HealthChanged:Connect(fn))
	    -- The old connection is automatically disconnected.
]]
function Butler:Set<T>(name: string, object: T, method: string?): T
	_alive(self, "Set")
	assert(type(name) == "string", "[Butler] name must be a string")
	assert(object ~= nil, "[Butler] Use :Remove(name) to clear a slot; :Set does not accept nil")

	-- Replace existing
	local old = self._named[name]
	if old then
		_log("Replacing slot:", name)
		_cleanItem(old.object, old.method, old.label)
	end

	self._named[name] = _entry(object, method, name)
	_log("Set slot:", name, "→", typeof(object))
	return object
end

--[[
	Has — returns true if a named slot is currently occupied.
]]
function Butler:Has(name: string): boolean
	return self._named[name] ~= nil
end

--[[
	Remove — clean and remove a single task by name string or object reference.
	Safe to call even if the task is not found.
]]
function Butler:Remove(nameOrObject: any)
	if type(nameOrObject) == "string" then
		local entry = self._named[nameOrObject]
		if entry then
			_cleanItem(entry.object, entry.method, entry.label)
			self._named[nameOrObject] = nil
			_log("Removed named:", nameOrObject)
		end
		return
	end

	-- Search anonymous tasks (reverse for stability while removing)
	for i = #self._tasks, 1, -1 do
		if self._tasks[i].object == nameOrObject then
			local entry = table.remove(self._tasks, i)
			if entry then
				_cleanItem(entry.object, entry.method, entry.label)
				_log("Removed anonymous task")
				return
			end
		end
	end

	-- Search named tasks by reference
	for name, entry in pairs(self._named) do
		if entry.object == nameOrObject then
			_cleanItem(entry.object, entry.method, entry.label)
			self._named[name] = nil
			_log("Removed named by ref:", name)
			return
		end
	end
end

-- ─── Introspection ───────────────────────────────────────────────────────────

--[[
	Count — total number of currently tracked tasks.
]]
function Butler:Count(): number
	local n = #self._tasks
	for _ in pairs(self._named) do n += 1 end
	return n
end

--[[
	IsAlive — true if Destroy() has NOT been called.
]]
function Butler:IsAlive(): boolean
	return not self._destroyed
end

-- ─── Signals ─────────────────────────────────────────────────────────────────

--[[
	Connect — track signal:Connect(fn). Returns the connection.
]]
function Butler:Connect(signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
	_alive(self, "Connect")
	return self:Add(signal:Connect(fn))
end

--[[
	Once — one-shot connection that auto-removes itself after firing.
	Unlike a raw signal:Once(), this also disconnects if the butler is
	destroyed before the signal ever fires — no dangling callbacks.
]]
function Butler:Once(signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
	_alive(self, "Once")
	local conn: RBXScriptConnection? = nil
	conn = signal:Connect(function(...)
		if conn then
			self:Remove(conn) -- remove before calling fn (prevents re-entry)
		end
		fn(...)
	end)
	return self:Add(conn :: RBXScriptConnection)
end

--[[
	Until — RxJS takeUntil pattern.
	Connects fn to listenSignal, but permanently stops listening the moment
	untilSignal fires. Both connections are tracked and cleaned normally.

	Example:
	    -- Update an NPC AI on Heartbeat until the NPC dies:
	    butler:Until(npc.Humanoid.Died, RunService.Heartbeat, function(dt)
	        updateNPC(dt)
	    end)
]]
function Butler:Until(
	untilSignal:  RBXScriptSignal,
	listenSignal: RBXScriptSignal,
	fn: (...any) -> ()
): RBXScriptConnection
	_alive(self, "Until")

	local listenConn: RBXScriptConnection? = nil
	local untilConn:  RBXScriptConnection? = nil

	listenConn = listenSignal:Connect(fn)
	untilConn  = untilSignal:Connect(function()
		if listenConn then
			self:Remove(listenConn)
		end
		if untilConn then
			self:Remove(untilConn)
		end
	end)

	local trackedListenConn = listenConn :: RBXScriptConnection
	local trackedUntilConn = untilConn :: RBXScriptConnection
	self:Add(trackedListenConn)
	self:Add(trackedUntilConn)
	return trackedListenConn
end

--[[
	ConnectMany — connect multiple signal→fn pairs at once.
	Accepts an array of {signal, fn} pairs.
	Returns an array of the created connections.

	    butler:ConnectMany({
	        { RunService.Heartbeat,   onHeartbeat },
	        { player.CharacterAdded, onCharacter  },
	        { workspace.ChildAdded,  onChildAdded },
	    })
]]
function Butler:ConnectMany(pairs_: { SignalHandlerPair }): { RBXScriptConnection }
	_alive(self, "ConnectMany")
	local conns: { RBXScriptConnection } = {}
	for i, pair in ipairs(pairs_) do
		local signal, fn = pair[1], pair[2]
		assert(typeof(signal) == "RBXScriptSignal" and type(fn) == "function",
			("[Butler] ConnectMany entry %d must be {signal, fn}"):format(i))
		table.insert(conns, self:Connect(signal :: RBXScriptSignal, fn :: (...any) -> ()))
	end
	return conns
end

-- ─── Constructing & Instances ────────────────────────────────────────────────

--[[
	Construct — create an object and immediately track it.
	Accepts a class table (calls .new(...)) or a constructor function.
]]
function Butler:Construct<T>(class: Constructor<T>, ...: any): T
	_alive(self, "Construct")
	local obj: T
	if type(class) == "function" then
		obj = (class :: FunctionConstructor<T>)(...)
	elseif type(class) == "table" and type((class :: any).new) == "function" then
		obj = (class :: TableConstructor<T>).new(...)
	else
		error("[Butler] Construct expects a function or a table with a .new constructor")
	end
	return self:Add(obj)
end

--[[
	Clone — clone an Instance and immediately track the clone.
]]
function Butler:Clone(instance: Instance): Instance
	_alive(self, "Clone")
	return self:Add(instance:Clone())
end

--[[
	AddInstance — track an instance and optionally parent it in one call.

	    local part = butler:AddInstance(Instance.new("Part"), workspace)
]]
function Butler:AddInstance(inst: Instance, parent: Instance?): Instance
	_alive(self, "AddInstance")
	if parent then
		inst.Parent = parent
	end
	return self:Add(inst)
end

-- ─── Async / Threads ─────────────────────────────────────────────────────────

--[[
	Task — spawn a tracked task.spawn coroutine.
	If the butler is destroyed while the task is running, task.cancel() is
	called on it — Luau equivalent of Rust's scoped thread joining on drop.

	    butler:Task(function()
	        while true do
	            doWork()
	            task.wait(0.05)
	        end
	    end)
]]
function Butler:Task(fn: () -> ()): thread
	_alive(self, "Task")
	return self:Add(task.spawn(fn))
end

--[[
	Delay — schedule a delayed call. The thread is tracked so it can be
	cancelled early if the butler cleans up before the delay expires.

	    butler:Delay(5, function()
	        print("5 seconds — or never if butler died first")
	    end)
]]
function Butler:Delay(t: number, fn: () -> ()): thread
	_alive(self, "Delay")
	return self:Add(task.delay(t, fn))
end

--[[
	Every — run a function on a fixed interval using a tracked coroutine.
	The loop ends automatically when the butler cleans up.
	No RunService wiring needed from the call site.

	    butler:Every(1/20, function()
	        updateMinimap()
	    end)
]]
function Butler:Every(interval: number, fn: () -> ()): thread
	_alive(self, "Every")
	local thread = task.spawn(function()
		while true do
			task.wait(interval)
			fn()
		end
	end)
	return self:Add(thread)
end

-- ─── Rust / C++ RAII patterns ────────────────────────────────────────────────

--[[
	Guard — Rust Drop trait / C++ ScopeGuard / unique_ptr with custom deleter.

	Attaches a cleanup function directly to a value. The function receives
	the value as its argument when the butler cleans up. This makes the
	coupling between a resource and its destructor local and explicit,
	rather than relying on method naming conventions.

	Unlike butler:Add(obj, "Method"), Guard lets you supply any arbitrary
	teardown logic, and keeps it right next to the acquisition site:

	    -- Acquisition and cleanup are co-located (RAII principle)
	    local lock  = butler:Guard(acquireLock(),  function(l) l:release() end)
	    local conn  = butler:Guard(openSocket(),   function(s) s:close() end)
	    local audio = butler:Guard(Sound:Play(),   function(s) s:Stop() end)

	Returns the value for inline use.
]]
function Butler:Guard<T>(value: T, cleanupFn: (value: T) -> ()): T
	_alive(self, "Guard")
	assert(type(cleanupFn) == "function", "[Butler] Guard requires a cleanup function")
	-- Wrap into a closure so _cleanItem calls it as a plain function
	self:Add(function()
		cleanupFn(value)
	end, nil, "Guard")
	return value
end

--[[
	Defer — C++ SCOPE_EXIT / Go `defer` / Rust defer! macro.

	Queues a zero-argument function to run at the NEXT Clean() or Destroy().
	The intent is explicit: "do this when this scope exits," regardless of
	how or when that happens.

	    butler:Defer(function()
	        Analytics:record("session_end")
	    end)

	Unlike Add(fn), Defer clearly communicates "this is a cleanup side-effect,
	not a tracked resource." Returns self for chaining.
]]
function Butler:Defer(fn: () -> ())
	_alive(self, "Defer")
	assert(type(fn) == "function", "[Butler] Defer requires a function")
	self:Add(fn, nil, "deferred")
	return self
end

-- ─── RxJS / Reactive patterns ────────────────────────────────────────────────

--[[
	Batch — register multiple cleanup items in one call.
	Inspired by RxJS CompositeDisposable and Kotlin's CompositeDisposable.

	Each item can be:
	  • A plain object (Add with no method)
	  • A {object, method} pair

	    butler:Batch({
	        conn1,
	        conn2,
	        { myTween,   "Cancel" },
	        { myAudio,   "Stop"   },
	    })

	Returns self for chaining.
]]
function Butler:Batch(items: { any })
	_alive(self, "Batch")
	for _, item in ipairs(items) do
		if type(item) == "table" and getmetatable(item) == nil and item[1] ~= nil then
			-- Treat as {object, method?} specification
			self:Add(item[1], item[2])
		else
			self:Add(item)
		end
	end
	return self
end

--[[
	OnClean — register a teardown observer.
	Inspired by RxJS finalize() operator. Fires AFTER all tasks are cleaned,
	every time Clean() or Destroy() is called. Useful for metrics, logging,
	or notifying other systems.

	    butler:OnClean(function()
	        ProfileService:EndSession(player)
	        print("Butler done.")
	    end)

	Returns self for chaining.
]]
function Butler:OnClean(fn: () -> ())
	_alive(self, "OnClean")
	assert(type(fn) == "function", "[Butler] OnClean requires a function")
	table.insert(self._onClean, fn)
	return self
end

--[[
	Wrap — TC39 Explicit Resource Management / Symbol.dispose pattern.

	Returns a DisposableHandle that proxies all method calls to the wrapped
	object, but adds a :Dispose() method that removes it from the butler
	early (before the next Clean/Destroy).

	This is the Luau equivalent of JavaScript's `using` keyword, which was
	proposed in TC39's Explicit Resource Management proposal:

	    // JavaScript (TC39)
	    using resource = openFile();
	    // resource.dispose() is called automatically at scope end

	In Butler:
	    local handle = butler:Wrap(openStream())
	    handle:Read(1024)           -- proxied to stream:Read(1024)
	    handle:Dispose()            -- early cleanup; removes from butler

	The object is still cleaned normally if Dispose() is never called.
]]
function Butler:Wrap<T>(object: T): DisposableHandle<T>
	_alive(self, "Wrap")
	self:Add(object)

	local handle = {} :: any
	setmetatable(handle, {
		__index = function(_, key: string)
			if key == "Dispose" then
				return function(_self: DisposableHandle<T>)
					self:Remove(object)
				end
			end
			local v = (object :: any)[key]
			if type(v) == "function" then
				-- Proxy: bind 'self' to the underlying object
				return function(_, ...)
					return v(object, ...)
				end
			end
			return v
		end,
		__tostring = function()
			return ("DisposableHandle<%s>"):format(typeof(object))
		end,
	})
	return handle :: DisposableHandle<T>
end

-- ─── Roblox QoL helpers ──────────────────────────────────────────────────────

--[[
	Tween — create, play, and track a Tween in one call.

	Unlike a plain :Add(tween), this calls :Cancel() before :Destroy() on
	cleanup, which is the correct Tween lifecycle. Roblox's :Destroy() alone
	does NOT stop a playing Tween — a common source of visual glitches when
	a butler cleans up mid-animation. This is a gap that Maid, Trove, and
	Janitor all have.

	    local tween = butler:Tween(
	        part,
	        TweenInfo.new(0.5, Enum.EasingStyle.Quad),
	        { CFrame = targetCFrame }
	    )
	    -- If butler:Destroy() fires mid-animation, the part stops immediately.

	Returns the Tween (not tracked directly — use the return value to
	chain :GetCompletedSignal() if needed).
]]
function Butler:Tween(instance: Instance, tweenInfo: TweenInfo, goals: { [string]: any }): Tween
	_alive(self, "Tween")
	local tween = TweenService:Create(instance, tweenInfo, goals)
	tween:Play()
	-- Wrap Cancel+Destroy in a closure rather than :Add(tween)
	-- so cleanup always calls Cancel first
	self:Add(function()
		tween:Cancel()
		tween:Destroy()
	end, nil, "Tween")
	return tween
end

--[[
	WaitFor — a tracked WaitForChild wrapper.

	The waiting thread is added to the butler so that if the butler is
	destroyed while waiting, the coroutine is cancelled and the wait
	is abandoned — no orphaned yields, no silent memory leaks.

	    local gui = butler:WaitFor(player.PlayerGui, "MainGui", 10)
	    if gui then
	        -- setup gui
	    end
]]
function Butler:WaitFor(inst: Instance, childName: string, timeout: number?): Instance?
	_alive(self, "WaitFor")
	local result: Instance? = nil
	local done = false

	local thread = task.spawn(function()
		result = inst:WaitForChild(childName, timeout or math.huge)
		done = true
	end)

	self:Add(thread, nil, "WaitFor:" .. childName)

	-- Yield current execution until the wait resolves or the thread is killed
	while not done and coroutine.status(thread) ~= "dead" do
		task.wait()
	end

	self:Remove(thread)
	return result
end

-- ─── Scoping & Linking ───────────────────────────────────────────────────────

--[[
	Scope — create a child Butler tied to this one.
	When the parent cleans, the child is also cleaned/destroyed.
	Inspired by Rust's std::thread::scope — work is bounded by parent lifetime.

	    local playerButler = Butler.new()

	    local charScope = playerButler:Scope()
	    charScope:Add(character)
	    charScope:Connect(character.Humanoid.Died, onDied)

	    -- When player leaves → playerButler:Destroy() → charScope:Destroy()
]]
function Butler:Scope()
	_alive(self, "Scope")
	local child = Butler.new()
	self:Add(child, nil, "Scope") -- child has Destroy(); auto-detected
	return child
end

--[[
	LinkToInstance — auto-destroy this butler when a Roblox Instance is removed.

	    butler:LinkToInstance(player)     -- destroys when player leaves
	    butler:LinkToInstance(char, true) -- cleans (but keeps alive) on death

	If allowReAdd = true, Clean() is called instead of Destroy() so you can
	re-add tasks to the same butler (e.g., re-setup on respawn).
	Replaces any previously set link.
]]
function Butler:LinkToInstance(instance: Instance, allowReAdd: boolean?): RBXScriptConnection
	_alive(self, "LinkToInstance")

	local linked = self._linked
	if linked then
		linked:Disconnect()
		self:Remove(linked)
	end

	local conn = instance.Destroying:Connect(function()
		if allowReAdd then
			self:Clean()
		else
			self:Destroy()
		end
	end)

	self._linked = conn
	self:Add(conn, nil, "InstanceLink")
	return conn
end

-- ─── Debug: Snapshot ─────────────────────────────────────────────────────────

--[[
	Snapshot — returns a human-readable table of all currently tracked tasks.
	Great for debugging mid-session to find leaks:

	    print(butler:Snapshot())
	    -- { [1] = "RBXScriptConnection", [2] = "thread", health = "table" }
]]
function Butler:Snapshot(): { [any]: string }
	local out: { [any]: string } = {}
	for i, entry in ipairs(self._tasks) do
		out[i] = entry.label or typeof(entry.object)
	end
	for name, entry in pairs(self._named) do
		out[name] = entry.label or typeof(entry.object)
	end
	return out
end

-- ─── Clean / Destroy ─────────────────────────────────────────────────────────

--[[
	Clean — clean all tasks and fire OnClean observers, but keep the butler
	alive for reuse. Useful for cyclic patterns (character respawn, round reset).

	Cleanup order (mirrors Rust's drop order for local variables):
	  1. Named tasks    — cleaned in arbitrary dictionary order
	  2. Anonymous tasks — cleaned in LIFO order (last added, first cleaned)
	  3. OnClean observers — fired after all tasks are gone
]]
function Butler:Clean()
	_log(("Clean(): %d tasks"):format(self:Count()))

	-- 1. Named
	for name, entry in pairs(self._named) do
		_cleanItem(entry.object, entry.method, entry.label)
		self._named[name] = nil
	end

	-- 2. Anonymous — LIFO
	for i = #self._tasks, 1, -1 do
		local entry = self._tasks[i]
		_cleanItem(entry.object, entry.method, entry.label)
		self._tasks[i] = nil
	end

	self._linked = nil

	-- 3. Teardown observers (RxJS finalize pattern)
	for _, fn in ipairs(self._onClean) do
		local ok, err = pcall(fn)
		if not ok then
			_warn(("OnClean observer error: %s"):format(tostring(err)))
		end
	end

	_log("Clean() complete.")
end

--[[
	Destroy — clean all tasks and permanently invalidate this butler.
	Calling Destroy() a second time is a safe no-op (double-free guard).
	After Destroy(), calling Add/Set/Connect etc. will error.
]]
function Butler:Destroy()
	if self._destroyed then
		return -- Double-destroy guard — matches Rust's idiomatic Drop behaviour
	end
	self._destroyed = true
	_log("Destroy() called.")
	self:Clean()
	table.clear(self._onClean) -- prevent re-firing if somehow called again
end

-- ─── Metamethods ─────────────────────────────────────────────────────────────

function Butler:__tostring(): string
	return ("Butler<%d tasks, %s>"):format(
		self:Count(),
		self._destroyed and "destroyed" or "alive"
	)
end

-- ─── Export ──────────────────────────────────────────────────────────────────

export type Butler = typeof(Butler.new())

return Butler
