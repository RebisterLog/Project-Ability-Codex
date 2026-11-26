-- Global placeholders for the shared limb-severing mechanic. Deliberately
-- independent of any spec/skin: every character uses the same wound assets
-- until the user swaps them in Studio.

const Config = {
	AssetsRoot = "SeveredLimbs",

	Animations = {
		Crawl = "Crawl",
		Run = "CrawlRun",
		Idle = "LieIdle",
	},

	Models = {
		Head = "Head",
		LeftArm = "LeftArm",
		RightArm = "RightArm",
		LeftLeg = "LeftLeg",
		RightLeg = "RightLeg",
		Torso = "Torso",
	},
}

return Config
