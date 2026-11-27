--!strict
--- Standalone regression test for bot stuck detection.
---
---   lune run tools/tests/StuckRules.test.luau
---
--- The bot must not be treated as stuck while its movement is locked by a
--- skill (Dash/Block/attack) or while a dash mover owns its velocity. A false
--- positive makes HandleStuck teleport the rig and zero its velocity, which
--- is exactly the "held in place / dash in place" symptom.

const StuckRules = require("../../src/server/services/BotService/NavigationController/StuckRules")

local function check(name: string, condition: boolean)
	if not condition then error("FAIL: " .. name) end
	print("PASS: " .. name)
end

local function ctx(elapsed: number, moved: number, walkSpeed: number, dashing: boolean)
	return {
		elapsed = elapsed,
		moved = moved,
		walkSpeed = walkSpeed,
		dashing = dashing,
	} :: StuckRules.Context
end

check("skill walk lock is not stuck", not StuckRules.ShouldRecover(ctx(2, 0, 0, false)))
check("slow cast lock is not stuck", not StuckRules.ShouldRecover(ctx(2, 0.1, 3, false)))
check("dash mover is not stuck", not StuckRules.ShouldRecover(ctx(2, 0, 25, true)))
check("short sample window is not stuck", not StuckRules.ShouldRecover(ctx(0.5, 0, 25, false)))
check("moving bot is not stuck", not StuckRules.ShouldRecover(ctx(2, 1, 25, false)))
check(
	"stationary bot with usable walk speed is stuck",
	StuckRules.ShouldRecover(ctx(2, 0.1, 25, false))
)
check(
	"threshold values are not stuck",
	not StuckRules.ShouldRecover(ctx(StuckRules.STUCK_TIME, StuckRules.STUCK_DISTANCE, 25, false))
)

print("StuckRules: all tests passed")
