--[=[
	Combat-only tuning shared by the server writer.

	CombatTimeout is the window after the last landed hit during which the
	replicated `CharacterState.InCombat` flag stays true. Repeated hits extend
	it; death or a respawn clears it immediately.
]=]

const Combat = {
	CombatTimeout = 10,
	PlayerMaxHealth = 350,
}

export type CombatConfig = typeof(Combat)

return Combat
