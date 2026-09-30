export type SpecInfo = {
	DisplayName: string,
	IsPublic: boolean,
	Binds: {
		[string]: { Enum.KeyCode & Enum.UserInputType },
	},
}

local Specs = {
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
}

return Specs
