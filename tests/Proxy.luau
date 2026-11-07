--!strict
--- Tests for `src/shared/packages/Proxy.luau`.
---
---   lune run tests/Proxy.luau
---
--- Covers what `docs/PROXY_REVIEW.md` asked for: delimited path keys, one index
--- lookup for exact subscriptions, a subtree `AnyChange` that reports the changed
--- leaf, wildcards, and a batch that survives a throwing listener.

local Proxy = require("../src/shared/packages/Proxy")

type Skill = { Parameters: { ReleaseTime: number, Enabled: boolean } }
type SkillSchema = { Skills: { [string]: Skill } }

local passed = 0
local failures: { string } = {}

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		return
	end

	table.insert(failures, if detail ~= nil then `{name}: {detail}` else name)
end

local function equal(name: string, actual: any, expected: any)
	check(name, actual == expected, `expected {tostring(expected)}, got {tostring(actual)}`)
end

-- CONSTRUCTION ---------------------------------------------------------------

do
	local source = { Name = "starter", Nested = { Count = 1 } }
	local proxy = Proxy(source)

	equal("construct: calling the proxy returns the source", proxy().Name, "starter")

	source.Nested.Count = 2
	equal("construct: the source is deep-copied", proxy().Nested.Count, 1)

	proxy().Nested.Count = 3
	equal("construct: the copy does not leak back", source.Nested.Count, 2)
end

-- EXACT SUBSCRIPTIONS --------------------------------------------------------

do
	local proxy = Proxy({ Level = 1 })
	local events: { { any } } = {}

	proxy:Subscribe("ChangeValue", { "Level" }, function(newValue, oldValue)
		table.insert(events, { newValue, oldValue })
	end)

	proxy:Patch({ { Name = "ChangeValue", Path = { "Level" }, Args = { 5 } } })

	equal("ChangeValue: one notification", #events, 1)
	equal("ChangeValue: new value", events[1][1], 5)
	equal("ChangeValue: old value", events[1][2], 1)
	equal("ChangeValue: state", proxy().Level, 5)
end

do
	local proxy = Proxy({ Level = 1 })
	local calls = 0

	proxy:Subscribe("ChangeValue", { "Level" }, function()
		calls += 1
	end)

	proxy:Patch({ { Name = "ChangeValue", Path = { "Level" }, Args = { 1 } } })

	equal("ChangeValue: an equal value is not a change", calls, 0)
end

do
	local proxy = Proxy({ Enabled = false })
	local old: any = nil

	proxy:Subscribe("ChangeValue", { "Enabled" }, function(_, previous)
		old = previous
	end)

	proxy:Patch({ { Name = "ChangeValue", Path = { "Enabled" }, Args = { true } } })

	equal("ChangeValue: a stored false survives path resolution", old, false)
end

do
	local proxy = Proxy({ List = { "a", "b" } })
	local seen = ""

	proxy:Subscribe("ChangeValue", { "List", "2" }, function(value)
		seen = value
	end)

	proxy:Patch({ { Name = "ChangeValue", Path = { "List", "2" }, Args = { "z" } } })

	equal("path: a numeric segment reaches the array", proxy().List[2], "z")
	equal("path: the numeric listener fired", seen, "z")
end

do
	local proxy = Proxy({ Data = {} })
	local calls = 0

	proxy:Subscribe("AnyChange", { "Data" }, function()
		calls += 1
	end)

	proxy:Patch({ { Name = "ChangeValue", Path = { "Missing", "Leaf" }, Args = { 1 } } })

	equal("path: a missing parent is not created", (proxy() :: any).Missing, nil)
	equal("path: a missing parent notifies nobody", calls, 0)
end

-- PATH KEYS ------------------------------------------------------------------

do
	local proxy = Proxy({ A = { B = 1 }, AB = 1 })
	local nested = 0
	local flat = 0

	proxy:Subscribe("ChangeValue", { "A", "B" }, function()
		nested += 1
	end)

	proxy:Subscribe("ChangeValue", { "AB" }, function()
		flat += 1
	end)

	proxy:Patch({ { Name = "ChangeValue", Path = { "AB" }, Args = { 2 } } })

	equal("path: `A/B` and `AB` are different keys", nested, 0)
	equal("path: the flat listener fired", flat, 1)
end

do
	local proxy = Proxy({ A = { B = 1 } })
	local calls = 0

	proxy:Subscribe("ChangeValue", { "A", "B" }, function()
		calls += 1
	end)

	proxy:Patch({ { Name = "ChangeValue", Path = "A/B", Args = { 2 } } })

	equal("path: `A/B` as a string equals the array form", calls, 1)
	equal("path: the string form wrote the leaf", proxy().A.B, 2)
end

do
	local proxy = Proxy({ Level = 1 })
	local calls = 0

	proxy:Subscribe("ChangeValue", { "Level" }, function()
		calls += 1
	end)

	proxy:Patch({ { Name = "ChangeValue", Path = "/Level", Args = { 2 } } })

	equal("path: a leading slash is ignored", calls, 1)
end

-- DICTIONARIES ---------------------------------------------------------------

do
	local state: SkillSchema = { Skills = {} }
	local proxy = Proxy(state)
	local args: { any } = {}

	proxy:Subscribe("SetDictionary", { "Skills" }, function(...)
		args = { ... }
	end)

	local skill: Skill = { Parameters = { ReleaseTime = 0, Enabled = true } }
	-- The annotation is load-bearing: the analyzer infers a nested array literal
	-- from its first element, so `Args = { "s1", skill }` inside the call below
	-- would be checked as `{ string }`.
	local setArgs: { any } = { "s1", skill }

	proxy:Patch({
		{ Name = "SetDictionary", Path = { "Skills" }, Args = setArgs },
	})

	equal("SetDictionary: key", args[1], "s1")
	equal("SetDictionary: new value", args[2], skill)
	equal("SetDictionary: old value", args[3], nil)
	equal("SetDictionary: state", proxy().Skills.s1, skill)

	proxy:Patch({
		{ Name = "RemoveDictionary", Path = { "Skills" }, Args = { "s1" } },
	})

	equal("RemoveDictionary: state", proxy().Skills.s1, nil)
end

do
	local state: SkillSchema = { Skills = {} }
	local proxy = Proxy(state)
	local calls = 0

	proxy:Subscribe("RemoveDictionary", { "Skills" }, function()
		calls += 1
	end)

	proxy:Patch({
		{ Name = "RemoveDictionary", Path = { "Skills" }, Args = { "absent" } },
	})

	equal("RemoveDictionary: a missing key is not a change", calls, 0)
end

-- ARRAYS ---------------------------------------------------------------------

do
	local proxy = Proxy({ List = { "a" } })
	local inserted: any = nil
	local index: any = nil

	proxy:Subscribe("InsertArray", { "List" }, function(value, at)
		inserted, index = value, at
	end)

	proxy:Patch({ { Name = "InsertArray", Path = { "List" }, Args = { "b" } } })

	equal("InsertArray: new value", inserted, "b")
	equal("InsertArray: the index is the inserted slot", index, 2)
	equal("InsertArray: state", proxy().List[2], "b")
end

do
	local proxy = Proxy({ List = { "a", "b" } })
	local removed: any = nil
	local removedIndex: any = nil

	proxy:Subscribe("RemoveArray", { "List" }, function(at, value)
		removedIndex, removed = at, value
	end)

	proxy:Patch({ { Name = "RemoveArray", Path = { "List" }, Args = { 1 } } })

	equal("RemoveArray: index", removedIndex, 1)
	equal("RemoveArray: old value", removed, "a")
	equal("RemoveArray: length", #proxy().List, 1)
end

-- CLEAR ----------------------------------------------------------------------

do
	local proxy = Proxy({ Skills = { a = 1 }, Flag = true })
	local previous: any = nil

	proxy:Subscribe("Clear", { "Skills" }, function(oldValue)
		previous = oldValue
	end)

	proxy:Patch({ { Name = "Clear", Path = { "Skills" } } })

	equal("Clear: the table is emptied", next(proxy().Skills), nil)
	equal("Clear: the old reference stays readable", previous.a, 1)

	proxy:Patch({ { Name = "Clear", Path = { "Flag" } } })

	equal("Clear: a primitive is reset", proxy().Flag, nil)
end

-- ANY CHANGE ----------------------------------------------------------------

do
	local state: SkillSchema = {
		Skills = {
			s1 = { Parameters = { ReleaseTime = 0, Enabled = true } },
		},
	}

	local proxy = Proxy(state)
	local subtree = 0
	local leaf = 0
	local newest: any = nil
	local oldest: any = nil

	proxy:Subscribe("AnyChange", { "Skills" }, function(newValue, oldValue)
		subtree += 1
		newest, oldest = newValue, oldValue
	end)

	proxy:Subscribe("AnyChange", { "Skills", "s1", "Parameters" }, function()
		leaf += 1
	end)

	local insertArgs: { any } = { "s2", { Parameters = { ReleaseTime = 3, Enabled = true } } }

	proxy:Patch({
		{
			Name = "SetDictionary",
			Path = { "Skills" },
			Args = insertArgs,
		},
	})

	equal("AnyChange: the parent hears a new entry", subtree, 1)
	equal("AnyChange: another id's leaf does not fire", leaf, 0)
	equal("AnyChange: the new value is the changed leaf", newest.Parameters.ReleaseTime, 3)
	equal("AnyChange: a new entry has no old value", oldest, nil)

	local cooldownArgs: { any } = { "ReleaseTime", 10 }

	proxy:Patch({
		{
			Name = "SetDictionary",
			Path = { "Skills", "s1", "Parameters" },
			Args = cooldownArgs,
		},
	})

	equal("AnyChange: a nested change reaches the subtree", subtree, 2)
	equal("AnyChange: the exact leaf fired", leaf, 1)
	equal("AnyChange: the reported value is the nested leaf", newest, 10)

	proxy:Patch({
		{ Name = "ChangeValue", Path = { "Skills" }, Args = { {} } },
	})

	equal("AnyChange: replacing a parent does not reach listeners below it", leaf, 1)
	equal("AnyChange: the parent itself still hears it", subtree, 3)
end

do
	local proxy = Proxy({ Value = 0 })
	local calls = 0

	local cleanup = proxy:Subscribe("AnyChange", { "Value" }, function()
		calls += 1
	end)

	proxy:Patch({ { Name = "ChangeValue", Path = { "Value" }, Args = { 1 } } })
	cleanup()
	proxy:Patch({ { Name = "ChangeValue", Path = { "Value" }, Args = { 2 } } })

	equal("cleanup: a removed listener stops receiving", calls, 1)
end

-- WILDCARDS ------------------------------------------------------------------

do
	local state: SkillSchema = {
		Skills = {
			s1 = { Parameters = { ReleaseTime = 0, Enabled = false } },
		},
	}

	local proxy = Proxy(state)
	local parameters = 0
	local deep = 0

	proxy:Subscribe("AnyChange", { "Skills", "*", "Parameters" }, function()
		parameters += 1
	end)

	proxy:Subscribe("AnyChange", { "Skills", "**" }, function()
		deep += 1
	end)

	local enabledArgs: { any } = { "Enabled", true }

	proxy:Patch({
		{
			Name = "SetDictionary",
			Path = { "Skills", "s1", "Parameters" },
			Args = enabledArgs,
		},
	})

	equal("pattern: `*` matches exactly one segment", parameters, 1)
	equal("pattern: `**` matches a deeper path", deep, 1)
end

do
	local proxy = Proxy({
		Skills = {
			s1 = { Enabled = false },
			s2 = { Enabled = false },
		},
	})

	local calls = 0

	proxy:Subscribe("ChangeValue", { "Skills", "*", "Enabled" }, function()
		calls += 1
	end)

	proxy:Patch({
		{ Name = "ChangeValue", Path = { "Skills", "s1", "Enabled" }, Args = { true } },
	})

	proxy:Patch({
		{ Name = "ChangeValue", Path = { "Skills", "s2", "Enabled" }, Args = { true } },
	})

	proxy:Patch({
		{ Name = "ChangeValue", Path = { "Skills", "s1" }, Args = { { Enabled = true } } },
	})

	equal("pattern: an exact-instruction wildcard matches each sibling", calls, 2)
	equal("pattern: a shorter path does not match the wildcard", proxy().Skills.s1.Enabled, true)
end

-- ON PATCH -------------------------------------------------------------------

do
	local proxy = Proxy({ Level = 1 })
	local batches: { { Proxy.Instruction } } = {}

	proxy:OnPatch(function(instructions)
		table.insert(batches, instructions)
	end)

	proxy:Patch({
		{ Name = "ChangeValue", Path = "Level", Args = { 2 } },
		{ Name = "ChangeValue", Path = { "Level" }, Args = { 2 } },
		{ Name = "Nope" :: any, Path = { "Level" }, Args = { 3 } },
		{ Name = "ChangeValue", Path = {}, Args = { 4 } },
	})

	equal("OnPatch: one call per batch", #batches, 1)
	equal("OnPatch: only applied instructions are forwarded", #batches[1], 1)

	local forwarded = batches[1][1]
	local path = forwarded.Path :: { string }

	equal("OnPatch: the forwarded path is the array form", path[1], "Level")
	equal("OnPatch: the forwarded instruction keeps its name", forwarded.Name, "ChangeValue")

	proxy:Patch({ { Name = "ChangeValue", Path = { "Level" }, Args = { 2 } } })

	equal("OnPatch: a no-op batch is not forwarded", #batches, 1)
end

-- ERROR ISOLATION ------------------------------------------------------------

do
	local proxy = Proxy({ Value = 0 })
	local seen = false
	local patched = false

	proxy:Subscribe("ChangeValue", { "Value" }, function()
		error("listener failure by design")
	end)

	proxy:Subscribe("ChangeValue", { "Value" }, function()
		seen = true
	end)

	proxy:OnPatch(function()
		patched = true
	end)

	proxy:Patch({ { Name = "ChangeValue", Path = { "Value" }, Args = { 1 } } })

	equal("isolation: the next listener still ran", seen, true)
	equal("isolation: OnPatch still ran", patched, true)
	equal("isolation: the change was applied", proxy().Value, 1)
end

print(`[tests.Proxy] passed: {passed}, failed: {#failures}`)

if #failures > 0 then error(table.concat(failures, "\n"), 0) end
