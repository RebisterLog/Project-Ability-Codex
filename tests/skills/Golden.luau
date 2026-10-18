--!strict
--- Golden traces: the whole effect list of a skill, compared with the text
--- recorded when the suite was written.
---
---   lune run tests/skills/Golden.luau             compare
---   lune run tests/skills/Golden.luau --update    rewrite the goldens
---
--- This is the tier that catches silent balance drift. A human reading a playtest
--- will not notice that a hit went from 15 to 20 damage or that the hitbox moved
--- from frame 20 to 21; a diff will.
---
--- The comparison is deliberately narrow: only what the skill *does* is recorded,
--- not coordinates or asset identities, so an unrelated change of a hitbox offset
--- does not produce noise here — that belongs to a hand-written assertion.

local Support = require("../support/Support")

local process = require("@lune/process")

--- Skills under this net. A skill missing here is simply not compared; adding a
--- name is what puts it under it, and `--update` then records what it does today.
const GOLDENS = {
	"Standless/Uppercut",
	"Standless/Footrest",
	"Standless/CircularKick",
	"Standless/DualPistols",
	"Standless/KnifeStab",
	"StandBarrage",
	"Summon",
}

local update = false

for _, arg in process.args do
	if arg == "--update" then update = true end
end

local passed = 0
local failures: { string } = {}

for _, skill in GOLDENS do
	if not Support.hasGolden(skill) and not update then
		table.insert(failures, `{skill}: no golden, run with --update`)
		continue
	end

	local ok, lines = pcall(Support.capture, skill)

	if not ok then
		table.insert(failures, `{skill}: {tostring(lines)}`)
		continue
	end

	if update then
		Support.write(skill, lines)
		passed += 1
		continue
	end

	local problems = Support.compare(skill, lines)

	if #problems == 0 then
		passed += 1
		continue
	end

	for _, problem in problems do
		table.insert(failures, `{skill} {problem}`)
	end
end

print(`[tests.skills.Golden] passed: {passed}, failed: {#failures}`)

if #failures > 0 then error(table.concat(failures, "\n"), 0) end
