--!strict
--- A log of what the skill did.
---
--- The service stand-ins do not perform effects — they record them. The test
--- then asks the log: "was there a hit on frame 20", "with what damage", "did
--- the skill set a parameter and take it back down". That is what replaces the
--- playtest: the behavior is visible as text rather than to the eye.
---
--- Every record carries the frame it happened on, so checking timing is no
--- different from checking the effect itself.

local Trace = {}
Trace.__index = Trace

--- The log is deliberately untyped: the records are of arbitrary shape, a skill
--- writes into them whatever it sees fit, and a strict type here would only get
--- in the way. The type exists so that `World.trace` does not read as unknown.
export type Trace = any

function Trace.new(): Trace
	local self = setmetatable({
		frame = 0,
		entries = {},
	}, Trace)

	self.counters = {
		hitbox = 0,
		attack = 0,
		parameter = 0,
		effect = 0,
		armor = 0,
	}

	return self
end

--- Current frame: a skill inside a step has to land in the records.
function Trace.setFrame(self: Trace, frame: number)
	self.frame = frame
end

function Trace.record(self: Trace, kind: string, data: { [string]: any })
	local index = self.counters[kind]

	if index == nil then
		index = 0
		self.counters[kind] = 0
	end

	index += 1
	self.counters[kind] = index

	local entry: { [string]: any } = { frame = self.frame, kind = kind }

	for key, value in data do
		entry[key] = value
	end

	table.insert(self.entries, { kind = kind, index = index, data = entry })

	return entry
end

--- Queries hand back copies: the test receives what was recorded, not live
--- references to internal tables the skill could still edit.

local function query(self: Trace, kind: string): { { [string]: any } }
	local result: { { [string]: any } } = {}

	for _, entry in self.entries do
		if entry.kind == kind then table.insert(result, entry.data) end
	end

	return result
end

function Trace.hitboxes(self: Trace)
	return query(self, "hitbox")
end

function Trace.attacks(self: Trace)
	return query(self, "attack")
end

function Trace.parameters(self: Trace)
	return query(self, "parameter")
end

function Trace.effects(self: Trace)
	return query(self, "effect")
end

function Trace.armor(self: Trace)
	return query(self, "armor")
end

--- All records by effect kind: `trace:effect("Animation")` gives animations only.
function Trace.effect(self: Trace, name: string)
	const result: { { [string]: any } } = {}

	for _, entry in self:effects() do
		if entry.name == name then table.insert(result, entry) end
	end

	return result
end

--- Attacks by target: handy for asserting "exactly one hit per target".
function Trace.against(self: Trace, victim: any): { { [string]: any } }
	const result: { { [string]: any } } = {}

	for _, entry in self:attacks() do
		if entry.victim == victim then table.insert(result, entry) end
	end

	return result
end

function Trace.clear(self: Trace)
	table.clear(self.entries)
	self.counters = { hitbox = 0, attack = 0, parameter = 0, effect = 0, armor = 0 }
end

return Trace
