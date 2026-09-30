--!strict
--!native
--!optimize 2

--[[
    DraftController module provides utilities for manipulating nested tables,
    including path-based value access, table merging based on patterns,
    and generating change logs between table versions. Ideal for data migration
    and state management scenarios where schema evolution is required.

    Key Features:
    - Traverse nested tables and extract all leaf paths
    - Get/set values using dot-separated path notation
    - Merge tables by prioritizing template values over pattern defaults
    - Generate detailed change logs between table versions

    Example Usage:
        local DraftController = require(PATH_TO_DraftController)
        local changes = DraftController.conversion(oldData, newData)
        local merged = DraftController.merge(defaultPattern, userData)

        -- Example usage (not part of module export):

        local DraftController = require(PATH_TO_DraftController)

        local DATA_PATTERN = {
            Crystals = 100,-- added new property with default value for pattern
            Inventory = {},
            Money = 0,
            Pets = {}
        }

        local OLD_VERSION = {
            Inventory = {
                {name = "sword", skin = "diamond"},
            },

            Money = 100,

            Pets = {
                ["dog"] = {name = "GG"},
            }
        }

        local NEW_VERSION = {
            Inventory = {
                --removed {name = "sword", skin = "diamond"},
            },

            --changed 100 -> 200
            Money = 200,

            Pets = {
                --change property name
                ["dog"] = {name = "WP"},

                -- added new pet
                ["cat"] = {name = "EZ"},
            }
        }

        local changes = DraftController.conversion(OLD_VERSION, NEW_VERSION)
        local merged = DraftController.merge(DATA_PATTERN, NEW_VERSION)

        print("------CHANGES------")
        print(changes)

        print("------MERGED------")
        print(merged)

        ----RESULTS----
        --[[
            ------CHANGES------
            {
                [1] =  ▼  {
                    ["action"] = "remove",
                    ["path"] = "Inventory.1.name",
                    ["value"] = "sword"
                },
                [2] =  ▼  {
                    ["action"] = "remove",
                    ["path"] = "Inventory.1.skin",
                    ["value"] = "diamond"
                },
                [3] =  ▼  {
                    ["action"] = "change",
                    ["path"] = "Pets.dog.name",
                    ["value"] = "WP"
                },
                [4] =  ▼  {
                    ["action"] = "change",
                    ["path"] = "Money",
                    ["value"] = 200
                },
                [5] =  ▼  {
                    ["action"] = "add",
                    ["path"] = "Pets.cat.name",
                    ["value"] = "EZ"
                }
            }
            ------MERGED------
            {
                ["Crystals"] = 100,
                ["Inventory"] = {},
                ["Money"] = 200,
                ["Pets"] =  ▼  {
                    ["cat"] =  ▼  {
                        ["name"] = "EZ"
                    },
                    ["dog"] =  ▼  {
                        ["name"] = "WP"
                    }
                }
            }
        ]]
--
--]]

--[[
    Counts all keys in a table (including non-array keys).

    Example:
        local t = {a = 1, b = 2, [3] = "three"}
        local size = getTabSize(t)  -- Returns 3

    @param t any Table to measure
    @return number Total key count
--]]
local function getTabSize(t: any): number
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	return count
end

local function isArray(t: any)
	if type(t) ~= "table" then return false end
	return #t > 0
end

--[[
    Recursively collects all dot-separated paths to leaf values in a table.
    Empty subtables are treated as leaves.

    Example:
        local t = {
            health = 100,
            inventory = {
                weapons = {"sword"},
                potions = {}
            }
        }
        local paths = getTabIndexesTree(t)
        -- Returns: {"health", "inventory.weapons.1", "inventory.potions"}

    @param tab {[any]: any} Table to traverse
    @param prefix string? Optional path prefix for recursion
    @return {string} List of dot-separated paths
--]]
local function getTabIndexesTree(tab: { [any]: any }, prefix: string?): { string }
	local tree = {}

	for index, value in pairs(tab) do
		local newPrefix = prefix and (prefix .. "." .. tostring(index)) or tostring(index)

		if type(value) == "table" then
			if isArray(value) and getTabSize(value) > 0 then
				table.insert(tree, newPrefix)
				continue
			end

			if getTabSize(value) == 0 then
				table.insert(tree, newPrefix)
			else
				local subTree = getTabIndexesTree(value, newPrefix)
				for _, path in pairs(subTree) do
					table.insert(tree, path)
				end
			end
		else
			table.insert(tree, newPrefix)
		end
	end

	return tree
end

--[[
    Sets a value at a dot-separated path in a nested table, creating intermediate tables as needed.

    Example:
        local t = {}
        setValueOnPath(t, "player.stats.level", 5)
        -- Results in: {player = {stats = {level = 5}}}

    @param tab {[any]: any} Root table
    @param path string Dot-separated path (e.g., "a.b.c")
    @param value any Value to set at the path
--]]
local function setValueOnPath(tab: { [any]: any }, path: string, value: any): ()
	local keys = string.split(path, ".")

	for i = 1, #keys - 1 do
		local key = keys[i]
		if not tab[key] then tab[key] = {} end
		tab = tab[key]
	end

	tab[keys[#keys]] = value
end

--[[
    Retrieves value at a dot-separated path with optional depth limiting.

    Example 1 (standard access):
        local t = {player = {score = 100}}
        local val, depth = getValueOnPath(t, "player.score")
        -- val = 100, depth = 2

    Example 2 (with maxLevel):
        local t = {player = {inventory = {sword = true}}}
        local val, depth = getValueOnPath(t, "player.inventory.sword", 2)
        -- val = {sword = true}, depth = 2

    @param tab {[any]: any} Root table
    @param path string Dot-separated path
    @param maxLevel number? Optional depth limit
    @return any? Value at path or intermediate node
    @return number Actual depth reached
--]]
local function getValueOnPath(tab: { [any]: any }, path: string, maxLevel: number?): (any?, number)
	local keys = string.split(path, ".")

	for i, key in ipairs(keys) do
		if not tab or type(tab) ~= "table" then return nil, i - 1 end

		if maxLevel and i == maxLevel then return tab[key], i end

		tab = tab[key] or tab[tonumber(key)]
	end

	return tab, #keys
end

--[[
    Merges two tables where:
    - Values from `template` override `pattern` at matching paths
    - Missing paths in `template` use values from `pattern`
    - Only paths existing in `pattern` are considered

    Example:
        local pattern = {coins = 0, items = {potion = 1}}
        local template = {coins = 10, items = {elixir = 1}}
        local result = merge(pattern, template)
        Result: {
            coins = 10,           -- Overridden by template
            items = {elixir = 1}  -- Entire subtree replaced
        }

    @param pattern {[any]: any} Base table with default structure/values
    @param template {[any]: any} Table containing override values
    @return {[any]: any} New merged table
--]]
local function merge<A, B>(pattern: A, template: B): A & B
	local result = {}

	local patternPaths = getTabIndexesTree(pattern)

	for _, path in ipairs(patternPaths) do
		local templateValue = getValueOnPath(template, path)
		local patternValue = getValueOnPath(pattern, path)

		if templateValue ~= nil then
			setValueOnPath(result, path, templateValue)
		else
			setValueOnPath(result, path, patternValue)
		end
	end

	return result
end

local function areTablesEqual<T, V>(a: T & {}, b: V & {}): boolean
	for i, v in pairs(a) do
		if b[i] ~= v then return false end
	end

	for i, v in pairs(b) do
		if a[i] ~= v then return false end
	end

	return true
end

--[[
    Generates a changelog comparing two table versions.
    Detects added, removed, and modified leaf values.

    Example:
        local old = {gold = 10, pets = {cat = "Mittens"}}
        local new = {gold = 20, pets = {dog = "Rex"}}
        local changes = conversion(old, new)
        Returns {
            {action = "change", path = "gold", value = 20},
            {action = "remove", path = "pets.cat", value = "Mittens"},
            {action = "add", path = "pets.dog", value = "Rex"}
        }

    @param oldVersion {[any]: any} Original table state
    @param newVersion {[any]: any} Updated table state
    @return {{action: string, path: string, value: any}} List of changes
--]]
local function conversion(
	oldVersion: { [any]: any },
	newVersion: { [any]: any }
): { { action: string, path: string, value: any } }
	local changes = {}

	local oldPaths = getTabIndexesTree(oldVersion)
	local newPaths = getTabIndexesTree(newVersion)

	for _, path in pairs(oldPaths) do
		local newValue = getValueOnPath(newVersion, path)
		local oldValue = getValueOnPath(oldVersion, path)

		if isArray(newValue) and isArray(oldValue) then
			if areTablesEqual(newValue :: {}, oldValue :: {}) then continue end

			table.insert(changes, {
				path = path,
				value = newValue,
				action = "change",
			})
			continue
		end

		-- CHANGED VALUE
		if newValue ~= nil and oldValue ~= nil and newValue ~= oldValue then
			table.insert(changes, {
				path = path,
				value = newValue,
				action = "change",
			})

			-- REMOVED VALUE
		elseif newValue == nil and oldValue ~= nil then
			table.insert(changes, {
				path = path,
				value = oldValue,
				action = "remove",
			})
		end
	end

	for _, path in pairs(newPaths) do
		local newValue, newLevel = getValueOnPath(newVersion, path)
		local oldValue, oldLevel = getValueOnPath(oldVersion, path)

		if newLevel >= oldLevel and newValue ~= nil and oldValue == nil then
			local actualValue = getValueOnPath(newVersion, path, newLevel)
			table.insert(changes, {
				path = path,
				value = actualValue,
				action = "add",
			})
		end
	end

	return changes
end

return {
	conversion = conversion,
	getValueOnPath = getValueOnPath,
	setValueOnPath = setValueOnPath,
	getTabSize = getTabSize,
	getTabIndexesTree = getTabIndexesTree,
	merge = merge,
}
