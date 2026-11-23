export type BindKey = Enum.KeyCode & Enum.UserInputType

export type SpecInfo = {
	DisplayName: string,
	IsPublic: boolean,
	Type: ("Spec" | "SubSpec")?,
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
			--["Grab"] = Enum.KeyCode.X,
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
			["Charge"] = { Key = Enum.KeyCode.LeftAlt, Hold = true },
			["SendoHamon"] = Enum.KeyCode.B,
			["PluckAndLuck"] = Enum.KeyCode.Y,
			["YellowOverdrive"] = { Key = Enum.KeyCode.X, Hold = true },
			["SilverPierce"] = Enum.KeyCode.Z,
		},
	},

	-- Hamon SubSpec: combat skills for Hamon bots and the asset source for the
	-- shared Charge skill (`BaseSpec = "Hamon"`).
	["Hamon"] = {
		Type = "SubSpec",
		DisplayName = "Hamon",
		IsPublic = false,

		Binds = {
			["Charge"] = { Key = Enum.KeyCode.LeftAlt, Hold = true },
			["SendoHamon"] = Enum.KeyCode.B,
			["PluckAndLuck"] = Enum.KeyCode.Y,
			["YellowOverdrive"] = { Key = Enum.KeyCode.X, Hold = true },
			["SilverPierce"] = Enum.KeyCode.Z,
		},
	},
}

return Specs
