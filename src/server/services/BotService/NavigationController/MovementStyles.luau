const MovementStyles = {
	direct = "direct",
	strafe = "strafe",
	zigzag = "zigzag",
	flank = "flank",
	bait = "bait",
	puma = "puma",
}

export type MovementStyle = keyof<typeof(MovementStyles)>

return MovementStyles
