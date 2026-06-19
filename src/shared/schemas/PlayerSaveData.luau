--!strict

type Bind = Enum.KeyCode|Enum.UserInputType

type SkinData = {
	Id: string, -- id(name) of Skin
	ReceivedTime: number,
	FirstOwnerId: number,
}

type SpecData = {
	Id: string, -- id(name) of Spec
	ReceivedTime: number,
	FirstOwnerId: number,
}

export type PlayerSaveData = {
	Money: number,
	Inventory: {string},
	
	SpecBinds: {[string]: {[string]: Bind}}, -- [specId]: {[skillId]: keycode}
	Skins: {[string]: SkinData}, -- [unique id]: data
	Specs: {[string]: SpecData}, -- [unique id]: data
	
	Spec: string,
}

return {
	Money = 0,
	Inventory = {},
	
	Skins = {},
	Specs = {},
	
	Spec = "Standless"
} :: PlayerSaveData