export type SpecInfo = {
	DisplayName: string,
	IsPublic: boolean,
	Type: ("Spec" | "SubSpec")?,
	Binds: {
		[string]: { Enum.KeyCode & Enum.UserInputType },
	},
}

const Specs = {
	["Standless"] = {
		DisplayName = "Standless",
		IsPublic = true,

		Binds = {
			["Dash"] = Enum.KeyCode.C,
			["Block"] = Enum.KeyCode.F,
			["Punch"] = Enum.UserInputType.MouseButton1,
			["Run"] = Enum.KeyCode.LeftControl,
			["Grab"] = Enum.KeyCode.X,
			--
			["Footrest"] = Enum.KeyCode.E,
			["Uppercut"] = Enum.KeyCode.R,
			["CircularKick"] = Enum.KeyCode.G,
			["Counter"] = Enum.KeyCode.V,
			["DualPistols"] = Enum.KeyCode.T,
			["KnifeStab"] = Enum.KeyCode.Z,
		},
	},

	["Undyne"] = {
		DisplayName = "Undyne",
		IsPublic = true,

		Binds = {
			["Dash"] = Enum.KeyCode.C,
			["Block"] = Enum.KeyCode.F,
			["Punch"] = Enum.UserInputType.MouseButton1,
			["Run"] = Enum.KeyCode.LeftControl,
			["Grab"] = Enum.KeyCode.X,

			["Barrage"] = Enum.KeyCode.E,
			["ArcSpearStrike"] = Enum.KeyCode.R,
			["WaitALittleBit"] = Enum.KeyCode.G,
		},
	},

	["Gerson"] = {
		DisplayName = "Gerson",
		IsPublic = true,

		Binds = {
			["Dash"] = Enum.KeyCode.C,
			["Block"] = Enum.KeyCode.F,
			["Punch"] = Enum.UserInputType.MouseButton1,
			["Run"] = Enum.KeyCode.LeftControl,
			["Grab"] = Enum.KeyCode.X,

			["ShellLaunch"] = Enum.KeyCode.T,
			["Bonk"] = Enum.KeyCode.R,
		},
	},

	["TheWorld"] = {
		DisplayName = "The World",
		IsPublic = true,

		Binds = {
			["Dash"] = Enum.KeyCode.C,
			["Block"] = Enum.KeyCode.F,
			["Punch"] = Enum.UserInputType.MouseButton1,
			["Run"] = Enum.KeyCode.LeftControl,
			["Grab"] = Enum.KeyCode.X,
			["Summon"] = Enum.KeyCode.Q,

			["StandBarrage"] = Enum.KeyCode.E,
		},
	},

	["StarPlatinum"] = {
		DisplayName = "Star Platinum",
		IsPublic = true,

		Binds = {
			["Dash"] = Enum.KeyCode.C,
			["Block"] = Enum.KeyCode.F,
			["Punch"] = Enum.UserInputType.MouseButton1,
			["Run"] = Enum.KeyCode.LeftControl,
			["Grab"] = Enum.KeyCode.X,
			["Summon"] = Enum.KeyCode.Q,

			["StandBarrage"] = Enum.KeyCode.E,
			["GroundSlam"] = Enum.KeyCode.G,
			["StarFinger"] = Enum.KeyCode.R,
			["StarStrike"] = Enum.KeyCode.T,
			["GrabSlam"] = Enum.KeyCode.X,
		},
	},

	["Hamon"] = {
		Type = "SubSpec",
		DisplayName = "Hamon",
		IsPublic = true,

		Binds = {},
	},
}

return Specs
