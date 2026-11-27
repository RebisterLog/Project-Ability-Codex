--!strict
--- Regression test for the mark-effect cleanup and doc sync (Task 3).
---
---   lune run tools/tests/TheWorldMarkerCleanup.test.luau
---
--- The MarkIndicator effect and its skin asset key are gone, and both the
--- English notes and their Russian twins describe the renamed, mark-free
--- skills.

local fs = require("@lune/fs")

local function check(name: string, condition: boolean)
	if not condition then error("FAIL: " .. name) end
	print("PASS: " .. name)
end

check(
	"MarkIndicator effect is deleted",
	not fs.isFile("src/shared/effects/TheWorld/MarkIndicator.luau")
)

const skin = fs.readFile("src/shared/configs/Skins/TheWorld/None.luau")
check("skin drops the MarkIndicator key", skin:find("MarkIndicator", 1, true) == nil)

const contract = "obsidian/03-Combat/Skill contract and lifecycle.md"
const contractRu = "obsidian/i18n/ru/03-Combat/Skill contract and lifecycle (RU).md"
const input = "obsidian/02-Architecture/Input and BindService.md"
const inputRu = "obsidian/i18n/ru/02-Architecture/Input and BindService (RU).md"

const enContract = fs.readFile(contract)
check("EN contract names Knives", enContract:find("`Knives`", 1, true) ~= nil)
check("EN contract names DistanceSlam", enContract:find("`DistanceSlam`", 1, true) ~= nil)
check("EN contract explains manual cooldown", enContract:find("SetCooldown(20)", 1, true) ~= nil)
check("EN contract drops marked target", enContract:find("marked target", 1, true) == nil)
check("EN contract drops old id", enContract:find("MarkedKnives", 1, true) == nil)

const ruContract = fs.readFile(contractRu)
check("RU contract names Knives", ruContract:find("`Knives`", 1, true) ~= nil)
check("RU contract names DistanceSlam", ruContract:find("`DistanceSlam`", 1, true) ~= nil)
check("RU contract explains manual cooldown", ruContract:find("SetCooldown(20)", 1, true) ~= nil)
check(
	"RU contract drops marked target",
	ruContract:find("помеченной цели", 1, true) == nil
)
check("RU contract drops old id", ruContract:find("MarkedKnives", 1, true) == nil)

const enInput = fs.readFile(input)
check("EN input names Knives", enInput:find("(currently `Knives`)", 1, true) ~= nil)
check("EN input drops old id", enInput:find("MarkedKnives", 1, true) == nil)

const warning = fs.readFile("src/shared/effects/TheWorld/DistantSlamWarning.luau")
check("warning label uses the new name", warning:find("DISTANCE SLAM INCOMING", 1, true) ~= nil)

const ruInput = fs.readFile(inputRu)
check("RU input names Knives", ruInput:find("(сейчас `Knives`)", 1, true) ~= nil)
check("RU input drops old id", ruInput:find("MarkedKnives", 1, true) == nil)

print("TheWorldMarkerCleanup: all tests passed")
