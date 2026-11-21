export type BindKey = Enum.KeyCode & Enum.UserInputType

-- A bind is either the legacy bare enum or a declaration that also carries
-- per-skill input options. `Hold` makes BindService keep requesting the skill
-- while the key is down, instead of firing once on press.
export type BindDecl = BindKey | {
	Key: BindKey,
	Hold: boolean?,
}

export type SpecInfo = {
	DisplayName: string,
	IsPublic: boolean,
	Type: ("Spec" | "SubSpec")?,
	Binds: {
		[string]: BindDecl,
	},
}

const Specs = {
	["Standless"] = {
		DisplayName = "Standless",
		IsPublic = true,

		Binds = {
			["Dash"] = { Key = Enum.KeyCode.C, Hold = true },
			["Block"] = { Key = Enum.KeyCode.F, Hold = true },
			["Punch"] = { Key = Enum.UserInputType.MouseButton1, Hold = true },
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
			["Dash"] = { Key = Enum.KeyCode.C, Hold = true },
			["Block"] = { Key = Enum.KeyCode.F, Hold = true },
			["Punch"] = { Key = Enum.UserInputType.MouseButton1, Hold = true },
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
			["Dash"] = { Key = Enum.KeyCode.C, Hold = true },
			["Block"] = { Key = Enum.KeyCode.F, Hold = true },
			["Punch"] = { Key = Enum.UserInputType.MouseButton1, Hold = true },
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
			["Dash"] = { Key = Enum.KeyCode.C, Hold = true },
			["Block"] = { Key = Enum.KeyCode.F, Hold = true },
			["Punch"] = { Key = Enum.UserInputType.MouseButton1, Hold = true },
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
			["Dash"] = { Key = Enum.KeyCode.C, Hold = true },
			["Block"] = { Key = Enum.KeyCode.F, Hold = true },
			["Punch"] = { Key = Enum.UserInputType.MouseButton1, Hold = true },
			["Run"] = Enum.KeyCode.LeftControl,
			["Grab"] = Enum.KeyCode.X,
			["Summon"] = Enum.KeyCode.Q,

			["StandBarrage"] = Enum.KeyCode.E,
			["GroundSlam"] = Enum.KeyCode.G,
			["StarFinger"] = Enum.KeyCode.T,
			["StarStrike"] = Enum.KeyCode.R,
			["GrabSlam"] = Enum.KeyCode.X,
		},
	},

	["JonathanHamon"] = {
		Type = "SubSpec",
		DisplayName = "Jonathan Hamon",
		IsPublic = true,

		Binds = {
			["Charge"] = Enum.KeyCode.G,
			["SendoHamon"] = Enum.KeyCode.H,
			["PluckAndLuck"] = Enum.KeyCode.R,
			["YellowOverdrive"] = { Key = Enum.KeyCode.T, Hold = true },
			["SilverPierce"] = Enum.KeyCode.Y,
		},
	},

	-- Hamon SubSpec: combat skills for Hamon bots and the asset source for the
	-- shared Charge skill (`BaseSpec = "Hamon"`).
	["Hamon"] = {
		Type = "SubSpec",
		DisplayName = "Hamon",
		IsPublic = false,

		Binds = {
			["Charge"] = Enum.KeyCode.G,
			["SendoHamon"] = Enum.KeyCode.H,
			["PluckAndLuck"] = Enum.KeyCode.R,
			["YellowOverdrive"] = { Key = Enum.KeyCode.T, Hold = true },
			["SilverPierce"] = Enum.KeyCode.Y,
		},
	},
}

return Specs
