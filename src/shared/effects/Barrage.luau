local BarragingCharacters = {}

local Barrage = {
	onStart = function(character: Model)
		BarragingCharacters[character] = {}
	end,

	onStop = function(character: Model)
		BarragingCharacters[character] = nil
	end,
}

return Barrage