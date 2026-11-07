# Proxy Library Review

## Overview

The `Proxy` library is a reactive data synchronization system used throughout this project to track changes in replicated tables (`PlayerData`, `GameData`, etc.). It wraps source tables, deep-copies them on initialization, and notifies subscribers when values change via the `Patch` mechanism.

```
src/shared/packages/Proxy.luau (main implementation)
```

## ✅ Strengths

| Feature | Description |
|---------|-------------|
| **Reactive pattern** | No polling needed — callbacks fire instantly on changes |
| **Deep copy isolation** | Changes to proxy never mutate source data |
| **Path-based targeting** | Supports nested paths `["Skills", 1, "Name"]` |
| **Batch Patching** | Multiple updates applied atomically in one call |
| **Flexible path format** | Works with `{string}` arrays and `/`-separated strings |
| **Cleanup support** | Return value from `Subscribe` allows proper cleanup |

## ❌ Issues & Fixes

### Issue 1: Type System Errors

```lua
-- Problems in Proxy.luau:
TypeError: Unknown type 'keyof'
TypeError: Unknown type 'setmetatable'
TypeError: Type '() -> (any, a...)' does not have key '__listeners'
TypeError: Expected type table, got 'true | {string}'
```

**Fix:** Use proper Lua typing patterns instead of invalid syntax.

```lua
-- Instead of complex setmetatable with __call in type definition:
type ProxyData<T> = {
    __source: T,
    __listeners: { Listener },
}

type ProxyMethods<T> = {
    Patch: function(self: ProxyTab<T>, instructions: { Instruction }) -> (),
    Subscribe: function(...) -> CleanupFunction,
    OnPatch: function(self: ProxyTab<T>, callback: ...) -> (),
}

type ProxyTab<T> = ProxyData<T> & ProxyMethods<T>

-- Constructor:
local function New<T>(t: T)
    assert(type(t) == "table", "Proxy only accepts a table")
    
    local proxy = setmetatable({
        __source = DeepCopy(t),
        __listeners = {},
    }, {
        __call = function(self) return self.__source end,
        -- Assign methods properly:
        Patch = Proxy.Patch,
        Subscribe = Proxy.Subscribe,
        OnPatch = Proxy.OnPatch,
    }) :: ProxyTab<T>
    
    return proxy
end
```

### Issue 2: O(n) Listener Search

```lua
-- Current implementation (O(n)):
for _, listener in self.__listeners :: { Listener } do
    if listener.Instruction ~= instruction.Name then continue end
    if GetPathAsString(listener.Path) ~= GetPathAsString(path) then continue end
end
```

**Fix:** Index listeners by path key for O(1) lookups.

```lua
-- Improved data structure:
type ListenerIndex = {
    ["ChangeValue"] = { [string] = { listener, callback } },
    ["InsertArray"] = { [string] = { listener, callback } },
    -- ...
}

-- In Subscribe:
local key = GetPathKey(path)
if not self.__listeners[instruction.Name] then
    self.__listeners[instruction.Name] = {}
end
self.__listeners[instruction.Name][key] = { listener, callback }

-- In Patch (O(1)):
for _, listener in ipairs(self.__listeners[instruction.Name][pathKey]) do
    listener.Callback(table.unpack(results))
end
```

### Issue 3: Path String Comparison Issues

```lua
-- Current GetPathAsString:
local function GetPathAsString(path)
    local pathString = ""
    for _, v in path do
        pathString = pathString .. v  -- "A/B" == "AB" if values are "A" and "B"
    end
    return pathString
end

-- Current GetPathFromString:
function GetPathFromString(pathString)
    return pathString:split("/")  -- "/A/B" → {"", "A", "B"}
end
```

**Fix:** Normalize paths with proper delimiters and hash-based comparison.

```lua
local function GetPathKey(path)
    local keys = typeof(path) == "string" 
        and path:gmatch("[^/]+") 
        or path
    
    -- Remove empty entries, normalize
    for i, key in ipairs(keys) do
        if not key then table.remove(keys, i) end
    end
    
    return table.concat(keys, "_")  -- "Skills_1_Name" instead of "Skills1Name"
end

local hashTable = {}

function GetHashKey(path)
    local key = GetPathKey(path)
    if not hashTable[key] then
        -- Simple djb2 hash for fast comparison
        local h = 5381
        for c in string.byte(key, 0, -1) do
            h = ((h * 33) + c) % 2^32
        end
        hashTable[key] = { key, h }
    end
    return hashTable[key]
end

-- Use GetHashKey in listener comparison instead of string comparison
```

### Issue 4: `AnyChange` Doesn't Report Changes

```lua
["AnyChange"] = function(t, path)
    return GetValueByPath(t, path) -- Just returns current value!
end
```

**Fix:** Return change context (old/new values).

```lua
["AnyChange"] = function(t, path)
    local oldValue = GetValueByPath(t, path)
    -- Value hasn't changed yet — this fires on Patch, not just read
    return { newValue: oldValue }  -- Placeholder; real value comes from instruction results
end

-- Better approach: combine with instruction results
["AnyChange"] = function(t, path)
    if not path or #path == 0 then return end
    local oldVal = GetValueByPath(t, path)
    -- On actual change (via Patch), return { newValue, oldValue }
    -- This requires integration with Patch to pass current state
end
```

### Issue 5: No Support for Partial/Pattern Matching

**Current limitation:** Must specify exact paths. Can't subscribe to "all Skills" or "all Accessory values".

**Fix:** Add glob/pattern support.

```lua
-- New instruction type:
["WatchPath"] = function(t, path)
    -- Recursively watch all nested tables/arrays at the given prefix path
end

-- Usage

-- Every skill's own name, whatever the id:
playerProxy:Subscribe("AnyChange", {"Skills", "*", "Name"}, function(newName, oldName)
    print(oldName, "->", newName)
end)

-- Anything at any depth under Skills (`**` is one or more segments):
playerProxy:Subscribe("AnyChange", {"Skills", "**"}, function()
    refreshSkillList()
end)

-- One instruction at one path; wildcards are allowed on the instruction too:
playerProxy:Subscribe("ChangeValue", {"Skills", "*", "Enabled"}, function(enabled)
    updateBadge(enabled)
end)

-- Unsubscribe:
local cleanup = playerProxy:Subscribe("AnyChange", {"Skills"}, onSkillChanged)
cleanup()
```

`AnyChange` fires when the subscribed path is a prefix of the changed path: a listener on `{"Skills"}` hears `SetDictionary {"Skills"}` (touched leaf `{"Skills", id}`) and any deeper change, but replacing the whole parent with `ChangeValue {"Skills"}` does not notify listeners below it.

## ✅ Resolution status

| Issue | Status | What was done |
|---|---|---|
| 1. Type system errors | Resolved | Removed `keyof` and `setmetatable` from the types. The callable form is the intersection `(() -> T) & ProxyData<T> & ProxyMethods<T>`; the function type must come first or the analyzer drops callability. `luau-lsp analyze` reports zero findings for the module and for its call sites. |
| 2. O(n) listener search | Resolved | Subscriptions live in three buckets: `exact[instruction][pathKey]` (one hash lookup per instruction), `anyChange[pathKey]` (one lookup per segment of the touched path), and `patterns` (linear scan, only for `*`/`**` subscriptions). |
| 3. Path comparison | Resolved | `NormalizePath` drops empty segments, so `"/A/B"` equals `"A/B"`. `GetPathKey` escapes `%` and `/`, so `{"A", "B"}` and `{"AB"}` cannot collide. Numeric segments resolve to array indices. A stored `false` is no longer mistaken for a missing value. |
| 4. `AnyChange` reports nothing | Resolved | Listeners receive `(newValue, oldValue, instruction)`, taken from the instruction result: the values of the changed leaf, not of the subscribed path. A no-op does not notify. `OnPatch` receives only instructions that changed something, with a normalized `Path` array. |
| 5. No partial/pattern matching | Resolved | Prefix subscriptions (above) plus `*` (one segment) and `**` (one or more) wildcards, matched against the touched path for `AnyChange` and against the instruction path for exact subscriptions. |

Other changes made while implementing the review:

- `InsertArray` now reports the inserted index (`#array + 1`) instead of `nil`; `RemoveArray` reports the exact index it removed.
- `Clear` replaces a table with a fresh `{}` instead of iterating it, so the old reference stays readable inside callbacks; a primitive is reset to `nil`.
- An unknown instruction name or an empty path is skipped with a `warn` instead of erroring; the rest of the batch still applies.
- A throwing listener (or `OnPatch` handler) is reported with `warn` and does not stop the remaining listeners or the patch batch.
- The packet contract is unchanged: `OnPatch` forwards `{ Name, Path = {string}, Args = {any} }`, exactly what `Packets.luau` already declares.

## Tests

```bash
lune run tests/Proxy.luau   # 55 checks
```

The suite covers deep-copy isolation, path normalization and key collisions, every instruction, the `AnyChange` ctx and its documented direction, wildcards, cleanup, `OnPatch` forwarding, and listener error isolation. `tests/baseline/analysis.txt` no longer carries the nine legacy `Proxy.luau` findings.

