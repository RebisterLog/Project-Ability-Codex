--!strict

type Bind = Enum.KeyCode | Enum.UserInputType

export type SkinData = {
	Id: string, -- id(name) of Skin
	Spec: string, -- Spec name this skin belongs to
	ReceivedTime: number,
	FirstOwnerId: number,
}

export type SpecData = {
	Id: string, -- unique id
	Name: string, -- Spec name
	ReceivedTime: number,
	FirstOwnerId: number,
}

export type PlayerSaveData = {
	Money: number,
	Experience: number,
	Level: number,
	Inventory: { string },

	SpecBinds: { [string]: { [string]: Bind } }, -- [spec name]: {[skillId]: keycode}
	Skins: { [string]: SkinData }, -- [unique id]: data
	Specs: { [string]: SpecData }, -- [unique id]: data
	EquippedSkins: { [string]: string }, -- [unique id of owned spec]: skin name

	Spec: string,
	SubSpec: string,
}

return {
	Experience = 0,
	Level = 0,
	Money = 0,
	Inventory = {},

	Skins = {},
	Specs = {},
	EquippedSkins = {},

	Spec = "None",
	SubSpec = "None",
} :: PlayerSaveData
