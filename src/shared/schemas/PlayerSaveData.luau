--!strict

type Bind = Enum.KeyCode | Enum.UserInputType

type SkinData = {
	Id: string, -- id(name) of Skin
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

	Spec: string,
}

return {
	Expirience = 0,
	Level = 0,
	Money = 0,
	Inventory = {},

	Skins = {},
	Specs = {},

	Spec = "None",
} :: PlayerSaveData
