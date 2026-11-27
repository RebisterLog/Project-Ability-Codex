export type Bind = Enum.KeyCode | Enum.UserInputType

export type BindOption = {
	Bind: Bind,
	Label: string,
}

const Binds = {
	Allowed = {
		{ Bind = Enum.KeyCode.Q, Label = "Q" },
		{ Bind = Enum.KeyCode.E, Label = "E" },
		{ Bind = Enum.KeyCode.R, Label = "R" },
		{ Bind = Enum.KeyCode.T, Label = "T" },
		{ Bind = Enum.KeyCode.Y, Label = "Y" },
		{ Bind = Enum.KeyCode.G, Label = "G" },
		{ Bind = Enum.KeyCode.C, Label = "C" },
		{ Bind = Enum.KeyCode.V, Label = "V" },
		{ Bind = Enum.KeyCode.B, Label = "B" },
		{ Bind = Enum.KeyCode.X, Label = "X" },
		{ Bind = Enum.KeyCode.Z, Label = "Z" },
		{ Bind = Enum.KeyCode.F, Label = "F" },
		{ Bind = Enum.KeyCode.H, Label = "H" },
		{ Bind = Enum.KeyCode.J, Label = "J" },
		{ Bind = Enum.KeyCode.U, Label = "U" },
		{ Bind = Enum.KeyCode.N, Label = "N" },
		{ Bind = Enum.KeyCode.K, Label = "K" },

		{ Bind = Enum.KeyCode.One, Label = "1" },
		{ Bind = Enum.KeyCode.Two, Label = "2" },
		{ Bind = Enum.KeyCode.Three, Label = "3" },
		{ Bind = Enum.KeyCode.Four, Label = "4" },
		{ Bind = Enum.KeyCode.Five, Label = "5" },
		{ Bind = Enum.KeyCode.Six, Label = "6" },
		{ Bind = Enum.KeyCode.Seven, Label = "7" },
		{ Bind = Enum.KeyCode.Eight, Label = "8" },
		{ Bind = Enum.KeyCode.Nine, Label = "9" },
		{ Bind = Enum.KeyCode.Zero, Label = "0" },

		{ Bind = Enum.KeyCode.LeftControl, Label = "CTRL" },
		{ Bind = Enum.KeyCode.LeftAlt, Label = "ALT" },
		{ Bind = Enum.UserInputType.MouseButton1, Label = "M1" },
		{ Bind = Enum.UserInputType.MouseButton2, Label = "M2" },
	},

	HiddenSkills = {
		["Run"] = true,
	},
}

return Binds
