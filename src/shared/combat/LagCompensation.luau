--!strict
--- Pure lag-compensation math shared by the client (aim sampling) and the
--- server (hit resolution). Deliberately free of Roblox globals so the contract
--- can be exercised headlessly with `lune run tests/LagCompensation.luau`.
---
--- The timeline used here is the Chrono snapshot timeline (`os.clock()` on the
--- server). `Entity:GetTargetRenderTime()` already returns a value on that same
--- timeline (server send time minus interpolation buffer), so no extra clock
--- conversion is needed.

export type AimSample = {
	Normal: number?,
	Half: number?,
	ReceivedAt: number?,
}

local DEFAULT_MAX_REWIND = 0.35
local SAMPLE_TTL = 0.5
local MAX_SPEED = 32 -- studs/s, used only to inflate the broadphase query

local LagCompensation = {}

--- Bounded rewind window shared by the client sample validation and the server
--- hit resolution. Kept here so both sides agree on one value.
LagCompensation.MaxRewind = DEFAULT_MAX_REWIND

--- Rejects NaN, zero/uninitialized clocks and future timestamps, then clamps
--- the sample into a bounded window so a tampered/ancient client cannot rewind
--- arbitrarily far.
function LagCompensation.ClampAimTime(now: number, aimTime: number?, maxRewind: number?): number?
	if typeof(aimTime) ~= "number" or aimTime ~= aimTime or aimTime <= 0 then return nil end

	local window = maxRewind or DEFAULT_MAX_REWIND
	if not (window >= 0) then window = DEFAULT_MAX_REWIND end

	return math.clamp(aimTime, now - window, now)
end

--- Picks the render clock that matches the entity's tick mode and makes sure
--- the sample is still fresh. Half-ticked (distant) entities are rendered one
--- tick further in the past, hence their own clock.
function LagCompensation.ChooseTime(
	sample: AimSample?,
	halfTicked: boolean,
	now: number,
	maxRewind: number?
): number?
	if not sample then return nil end
	if (sample.ReceivedAt or 0) + SAMPLE_TTL < now then return nil end

	const aimTime = if halfTicked then sample.Half else sample.Normal
	return LagCompensation.ClampAimTime(now, aimTime, maxRewind)
end

--- How much to grow the overlap query so targets that have moved since the
--- aim instant still show up as broadphase candidates. The narrowphase always
--- re-tests them against their historical pose.
function LagCompensation.BroadphaseInflation(maxRewind: number?, speed: number?): number
	local window = maxRewind or DEFAULT_MAX_REWIND
	if not (window >= 0) then window = DEFAULT_MAX_REWIND end

	return window * (speed or MAX_SPEED)
end

--- Sphere-vs-OBB test in the box's object space. `localX/Y/Z` is the sphere
--- center transformed into the hitbox frame; `hx/hy/hz` are the hitbox half
--- extents. Used for box/sphere-less hitboxes after both attacker and target
--- poses have been rewound.
function LagCompensation.LocalSphereOverlapsBox(
	localX: number,
	localY: number,
	localZ: number,
	radius: number,
	hx: number,
	hy: number,
	hz: number
): boolean
	const dx = math.max(math.abs(localX) - hx, 0)
	const dy = math.max(math.abs(localY) - hy, 0)
	const dz = math.max(math.abs(localZ) - hz, 0)

	return dx * dx + dy * dy + dz * dz <= radius * radius
end

--- Sphere-vs-sphere test used by radius hitboxes.
function LagCompensation.SphereOverlapsSphere(
	distance: number,
	radiusA: number,
	radiusB: number
): boolean
	return distance <= radiusA + radiusB
end

return LagCompensation
