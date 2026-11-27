--!strict
--- Regression test for comment-free The World skills.
---
---   lune run tools/tests/TheWorldNoComments.test.luau

local fs = require("@lune/fs")

local function check(name: string, condition: boolean)
	if not condition then error("FAIL: " .. name) end
	print("PASS: " .. name)
end

const FILES = {
	"src/server/skills/TheWorld/Knives.luau",
	"src/server/skills/TheWorld/DistanceSlam.luau",
	"src/server/skills/TheWorld/LegBarrage.luau",
	"src/server/skills/TheWorld/StopSign.luau",
}

for _, path in FILES do
	const source = fs.readFile(path)
	const base = path:match("([^/]+)%.luau$") or path
	check(base .. " has no comments", source:find("--", 1, true) == nil)
end

const knives = fs.readFile(FILES[1])
check("knives still deal 2.5", knives:find("Damage = 2.5", 1, true) ~= nil)

const slam = fs.readFile(FILES[2])
check("slam still searches 50 studs", slam:find("SearchRadius = 50", 1, true) ~= nil)

const barrage = fs.readFile(FILES[3])
check("user barrage debug is kept", barrage:find("Debug = true", 1, true) ~= nil)

const sign = fs.readFile(FILES[4])
check("user sign debug is kept", sign:find("Debug = true", 1, true) ~= nil)

print("TheWorldNoComments: all tests passed")
