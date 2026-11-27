--!strict

--- Pure decision rule for stuck recovery. Kept free of Roblox globals so it
--- can be tested with lune (tools/tests/StuckRules.test.luau).
---
--- A bot whose movement is locked by a skill (Dash, Block, attacks) is not
--- stuck: the Humanoid simply cannot move. Treating that as a stall makes
--- HandleStuck teleport the rig and zero AssemblyLinearVelocity, which kills
--- dash momentum and looks like the bot is being held in place.

const StuckRules = {}

const STUCK_TIME = 1.5
const STUCK_DISTANCE = 0.75
const MIN_WALK_SPEED = 5

export type Context = {
	elapsed: number,
	moved: number,
	walkSpeed: number,
	dashing: boolean,
}

function StuckRules.ShouldRecover(ctx: Context): boolean
	if ctx.dashing then return false end
	if ctx.walkSpeed < MIN_WALK_SPEED then return false end
	if ctx.elapsed < STUCK_TIME then return false end

	return ctx.moved < STUCK_DISTANCE
end

StuckRules.STUCK_TIME = STUCK_TIME
StuckRules.STUCK_DISTANCE = STUCK_DISTANCE
StuckRules.MIN_WALK_SPEED = MIN_WALK_SPEED

return StuckRules
