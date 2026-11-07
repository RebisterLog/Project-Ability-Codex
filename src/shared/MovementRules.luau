--!strict

const MovementRules = {
	BaseWalkSpeed = 16,
	BaseJumpPower = 50,
	RunSpeed = 25,
}

export type Gates = {
	Alive: boolean,
	Stunned: boolean,
	Ragdolled: boolean,
	Restrained: boolean,
	Blocking: boolean,
	Physics: boolean,
}

function MovementRules.GetWalkSpeed(minWalkSpeed: number, maxWalkSpeed: number): number
	const effectiveMinWalkSpeed = math.min(minWalkSpeed, maxWalkSpeed)
	return math.clamp(MovementRules.BaseWalkSpeed, effectiveMinWalkSpeed, maxWalkSpeed)
end

function MovementRules.GetJumpPower(maxJumpPower: number): number
	return math.min(MovementRules.BaseJumpPower, maxJumpPower)
end

function MovementRules.CanRun(gates: Gates): boolean
	return gates.Alive
		and not gates.Stunned
		and not gates.Ragdolled
		and not gates.Restrained
		and not gates.Blocking
		and not gates.Physics
end

return MovementRules
