--!strict
--- `Buttler`/`Janitor` stand-in: bookkeeping of everything that has to go away.
---
--- Skills constantly write `self.Cleaner:Add(...)`, `seq.Cleaner:Set("Armor", ...)`
--- and `seq.Cleaner:Remove("Armor")`. A mistake here means a leak in the live
--- game — a visual effect that never stops, or a parameter that is never taken
--- back down — and such things are exactly what a playtest does not reveal.
---
--- This is also where the call log lives: a test can assert that a specific
--- object was removed, not merely that "something was removed".

local Butler = {}
Butler.__index = Butler

function Butler.new(name: string?): any
	local self = setmetatable({
		name = name,
		slots = {},
		order = {},
		cleaned = false,
		calls = {},
	}, Butler)

	return self
end

--- Accepts anything the code throws at it: a function, an object with `Destroy`,
--- a connection with `Disconnect`, or an already-faked `Buttler`.
local function release(value: any, method: string?): ()
	if type(value) == "function" then
		value()
		return
	end

	if type(value) ~= "table" then return end

	local target = if method
		then value[method]
		else value.Destroy or value.destroy or value.Disconnect or value.disconnect

	if type(target) == "function" then target(value) end
end

function Butler.track(self: any, value: any, method: string?)
	table.insert(self.order, { value = value, method = method })

	return value
end

function Butler.Add(self: any, value: any, method: string?)
	table.insert(self.calls, "Add")
	return self:track(value, method)
end

function Butler.AddChain(self: any, value: any, method: string?)
	self:Add(value, method)
	return self
end

function Butler.Set(self: any, name: string, value: any, method: string?)
	table.insert(self.calls, `Set({name})`)

	if self.slots[name] == nil then
		table.insert(self.order, { name = name, value = value, method = method })
	end

	self.slots[name] = value

	return value
end

--- Whether a named slot is currently held. Skills use it to toggle a held
--- effect (`Run` removes the speed boost on the second press instead of adding
--- a second one), so the answer has to reflect the real state of the slot
--- rather than "something was added at some point".
function Butler.Has(self: any, name: string): boolean
	table.insert(self.calls, `Has({name})`)

	return self.slots[name] ~= nil
end

--- Early targeted teardown: a skill drops its armor on frame 30 without waiting
--- for the sequence to end, and the test has to see that this really happened
--- before it finished.
function Butler.Remove(self: any, name: string)
	table.insert(self.calls, `Remove({name})`)

	local entry = self.slots[name]

	if entry == nil then return end

	release(entry)

	for index, item in self.order do
		if item.name == name then
			table.remove(self.order, index)
			break
		end
	end

	self.slots[name] = nil
end

--- Runs the cleanup but leaves the `Buttler` alive: that is exactly how
--- `Sequencer:Stop` behaves.
function Butler.Clean(self: any)
	if self.cleaned then return end
	self.cleaned = true

	for index = #self.order, 1, -1 do
		local item = self.order[index]
		release(item.value, item.method)
	end

	table.clear(self.order)
	table.clear(self.slots)
end

function Butler.Destroy(self: any)
	self:Clean()
	self.destroyed = true
end

function Butler.Count(self: any): number
	return #self.order
end

return Butler
