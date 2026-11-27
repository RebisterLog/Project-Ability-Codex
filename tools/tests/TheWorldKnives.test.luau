--!strict
--- Regression test for the damage-only knives skill (Task 1).
---
---   lune run tools/tests/TheWorldKnives.test.luau
---
--- Knives must deal damage without storing marks, publishing a shared mark
--- table, or starting the MarkIndicator effect. Asset lookup strings keep
--- their Studio names even though the skill id is now `Knives`.

local fs = require("@lune/fs")

local function check(name: string, condition: boolean)
	if not condition then error("FAIL: " .. name) end
	print("PASS: " .. name)
end

local KNIVES = "src/server/skills/TheWorld/Knives.luau"
local SPEC = "src/server/specs/TheWorld.luau"
local BINDS = "src/shared/configs/Specs.luau"
local CLIENT = "src/client/services/BindService.luau"
local BOT = "src/shared/configs/Bots/Dio.luau"

check("Knives module exists", fs.isFile(KNIVES))
check(
	"old MarkedKnives module is gone",
	not fs.isFile("src/server/skills/TheWorld/MarkedKnives.luau")
)

if not fs.isFile(KNIVES) then error("FAIL: cannot check the missing knives module") end
local knives = fs.readFile(KNIVES)

check("DisplayName is Knives", knives:find('DisplayName = "Knives"', 1, true) ~= nil)
check("no mark accumulator", knives:find("addMark", 1, true) == nil)
check("no mark cleanup", knives:find("clearMark", 1, true) == nil)
check("no Marks table", knives:find("self.Marks", 1, true) == nil)
check("no mark UUIDs", knives:find("MarkUUIDs", 1, true) == nil)
check("no MarkIndicator effect", knives:find("MarkIndicator", 1, true) == nil)
check("no shared mark table", knives:find("character.MarkedKnives", 1, true) == nil)
check("hits do not chain", knives:find(":andThen", 1, true) == nil)
check("damage is unchanged", knives:find("Damage = 2.5", 1, true) ~= nil)
check(
	"charge spend is unchanged",
	knives:find('ConsumeCharge(self.Character, "KnivesCharge", 1)', 1, true) ~= nil
)
check(
	"animation asset key is unchanged",
	knives:find('GetAsset("Animations/MarkedKnives")', 1, true) ~= nil
)
check(
	"throw sound key is unchanged",
	knives:find('GetAsset("Sounds/MarkedKnivesThrow")', 1, true) ~= nil
)
check("hit sound key is unchanged", knives:find('"Sounds/MarkedKnivesHit"', 1, true) ~= nil)
check("knife model key is unchanged", knives:find('GetAsset("Models/Knife")', 1, true) ~= nil)

local spec = fs.readFile(SPEC)
check("spec registers Knives", spec:find('["Knives"] = "@Specs/TheWorld/Knives"', 1, true) ~= nil)
check("spec drops MarkedKnives", spec:find("MarkedKnives", 1, true) == nil)

local binds = fs.readFile(BINDS)
check("bind is T", binds:find('["Knives"] = Enum.KeyCode.T', 1, true) ~= nil)
check("old bind is gone", binds:find("MarkedKnives", 1, true) == nil)

local client = fs.readFile(CLIENT)
check("client opts into aim for Knives", client:find("{ Knives = true }", 1, true) ~= nil)
check("client drops MarkedKnives", client:find("MarkedKnives", 1, true) == nil)

local bot = fs.readFile(BOT)
check("bot config uses Knives", bot:find('["Knives"] = {', 1, true) ~= nil)
check("bot combo uses Knives", bot:find('"Knives",', 1, true) ~= nil)
check("bot config drops MarkedKnives", bot:find("MarkedKnives", 1, true) == nil)

print("TheWorldKnives: all tests passed")
