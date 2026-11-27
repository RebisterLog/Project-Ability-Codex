--!strict
--- Regression test for the automatic DistanceSlam skill (Task 2).
---
---   lune run tools/tests/TheWorldDistanceSlam.test.luau
---
--- The skill must select the nearest enemy with a 50-stud radius query, spend
--- its cooldown on every cast, and keep one continuous movement-slow layer
--- that is released when the strike ends or when no enemy is in range.

local fs = require("@lune/fs")

local function check(name: string, condition: boolean)
	if not condition then error("FAIL: " .. name) end
	print("PASS: " .. name)
end

local function count(haystack: string, needle: string): number
	local total = 0
	local at = 1
	while true do
		const found = haystack:find(needle, at, true)
		if not found then break end
		total += 1
		at = found + 1
	end
	return total
end

const SLAM = "src/server/skills/TheWorld/DistanceSlam.luau"
const SPEC = "src/server/specs/TheWorld.luau"
const BINDS = "src/shared/configs/Specs.luau"
const BOT = "src/shared/configs/Bots/Dio.luau"

check("DistanceSlam module exists", fs.isFile(SLAM))
check(
	"old DistantSlam module is gone",
	not fs.isFile("src/server/skills/TheWorld/DistantSlam.luau")
)
if not fs.isFile(SLAM) then error("FAIL: cannot check the missing slam module") end
const slam = fs.readFile(SLAM)

check("DisplayName is Distance Slam", slam:find('DisplayName = "Distance Slam"', 1, true) ~= nil)
check("search radius is 50", slam:find("SearchRadius = 50", 1, true) ~= nil)
check("no mark helpers", slam:find("getMarkedKnives", 1, true) == nil)
check("no mark consumption", slam:find("clearAllMarks", 1, true) == nil)
check("no mark table", slam:find("marked.Marks", 1, true) == nil)
check("no mark count", slam:find("entry.Count", 1, true) == nil)
check("no word mark in the module", slam:lower():find("mark", 1, true) == nil)
check("radius query uses SearchRadius", slam:find("Size = self.Data.SearchRadius", 1, true) ~= nil)
check("nearest target first", slam:find("SortByDistance = true", 1, true) ~= nil)
check("target takes first hitbox result", slam:find("self.Target = targets[1]", 1, true) ~= nil)
check("search query does not fire Casted", count(slam, "Skill = self") == 1)
check("cooldown is explicit", slam:find("self:SetCooldown(20)", 1, true) ~= nil)

check("one walk-speed layer", count(slam, 'AddParameter("MaxWalkSpeed"') == 1)
check(
	"walk-speed layer is Medium",
	slam:find('AddParameter("MaxWalkSpeed", Enums.CastSpeed.Medium)', 1, true) ~= nil
)
check("one jump layer", count(slam, 'AddParameter("MaxJumpPower", 0)') == 1)
check(
	"slow is owned by strike cleaner",
	slam:find("self.StrikeSequence.Cleaner:Add(self.CastSlow)", 1, true) ~= nil
)
check(
	"no-jump is owned by strike cleaner",
	slam:find("self.StrikeSequence.Cleaner:Add(self.CastNoJump)", 1, true) ~= nil
)
check("slow released when no target", slam:find("self.CastSlow:Destroy()", 1, true) ~= nil)
check("no-jump released when no target", slam:find("self.CastNoJump:Destroy()", 1, true) ~= nil)

check("damage is unchanged", slam:find("Damage = 25", 1, true) ~= nil)
check("perfect block is unchanged", slam:find("PerfectBlockable = true", 1, true) ~= nil)
check("user strike debug is kept", slam:find("Debug = true", 1, true) ~= nil)
check("dead target guard is kept", slam:find("Humanoid.Health <= 0", 1, true) ~= nil)
check(
	"strike origin follows target",
	slam:find("Origin = CFrame.new(target.RootPart.Position)", 1, true) ~= nil
)
check(
	"interrupt cleans strike cleaner",
	slam:find("self.StrikeSequence.Cleaner:Clean()", 1, true) ~= nil
)

const spec = fs.readFile(SPEC)
check(
	"spec registers DistanceSlam",
	spec:find('["DistanceSlam"] = "@Specs/TheWorld/DistanceSlam"', 1, true) ~= nil
)
check("spec drops DistantSlam", spec:find("DistantSlam", 1, true) == nil)

const binds = fs.readFile(BINDS)
check("bind is G", binds:find('["DistanceSlam"] = Enum.KeyCode.G', 1, true) ~= nil)
check("old bind is gone", binds:find("DistantSlam", 1, true) == nil)

const bot = fs.readFile(BOT)
check("bot config uses DistanceSlam", bot:find('["DistanceSlam"] = {', 1, true) ~= nil)
check("bot distance is 50", bot:find("Distance = 50", 1, true) ~= nil)
check("bot config drops DistantSlam", bot:find("DistantSlam", 1, true) == nil)
check("bot comment drops full mark", bot:find("full mark", 1, true) == nil)

print("TheWorldDistanceSlam: all tests passed")
