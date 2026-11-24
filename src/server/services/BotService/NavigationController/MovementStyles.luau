const MovementStyles = {
	direct = "direct",
	strafe = "strafe",
	zigzag = "zigzag",
	flank = "flank",
	bait = "bait",
	puma = "puma",
	lunge = "lunge",
	orbit = "orbit",
	sidestep = "sidestep",
}

export type MovementStyle = keyof<typeof(MovementStyles)>

return MovementStyles
