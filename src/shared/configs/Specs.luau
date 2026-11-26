export type BindKey = Enum.KeyCode & Enum.UserInputType

export type SpecInfo = {
	DisplayName: string,
	IsPublic: boolean,
	Type: ("Spec" | "SubSpec")?,

	TimeStopVision: boolean?,

	Binds: {
		[string]: BindKey,
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
			["Summon"] = Enum.KeyCode.Q,

			["StandBarrage"] = Enum.KeyCode.E,

			["StopSign"] = Enum.KeyCode.R,
			["MarkedKnives"] = Enum.KeyCode.T,
			["LegBarrage"] = Enum.KeyCode.Y,
			["DistantSlam"] = Enum.KeyCode.G,
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
			["Summon"] = Enum.KeyCode.Q,

			["StandBarrage"] = Enum.KeyCode.E,
			["GroundSlam"] = Enum.KeyCode.G,
			["StarFinger"] = Enum.KeyCode.T,
			["StarStrike"] = Enum.KeyCode.R,
			["GrabSlam"] = Enum.KeyCode.V,
		},
	},

	["JonathanHamon"] = {
		Type = "SubSpec",
		DisplayName = "Jonathan Hamon",
		IsPublic = true,

		Binds = {
			["Charge"] = Enum.KeyCode.LeftAlt,
			["SendoHamon"] = Enum.KeyCode.B,
			["PluckAndLuck"] = Enum.KeyCode.Y,
			["YellowOverdrive"] = Enum.KeyCode.X,
			["SilverPierce"] = Enum.KeyCode.Z,
		},
	},
}

return Specs
