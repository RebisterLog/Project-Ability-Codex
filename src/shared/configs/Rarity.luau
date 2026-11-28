export type RarityInfo = {
	Name: string,
	Color: Color3,
	Order: number,
}

const Rarity: { [string]: RarityInfo } = {
	Common = { Name = "Common", Color = Color3.fromRGB(232, 232, 232), Order = 1 },
	Rare = { Name = "Rare", Color = Color3.fromRGB(0, 230, 118), Order = 2 },
	Legendary = { Name = "Legendary", Color = Color3.fromRGB(199, 154, 75), Order = 3 },
	Mythic = { Name = "Mythic", Color = Color3.fromRGB(255, 45, 111), Order = 4 },
}

return Rarity
