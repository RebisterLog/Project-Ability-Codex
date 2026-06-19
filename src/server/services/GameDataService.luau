local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Proxy = require(ReplicatedStorage.shared.packages.Proxy)

local Crane = require(ReplicatedStorage.shared.packages.Crane)
local GameDataSchema = require(ReplicatedStorage.shared.schemas.GameData)

local GameDataService = Crane:CreateService({
	Name = "GameDataService",
	LoadOrder = -100,
})

local url = "https://ipconfig.io/json"
local function GetRegionName(): string
	local response = HttpService:GetAsync(url, false) -- get the data from the API

	if response then -- if the data from API is successfully retrieved and is not nil
		local locationData = HttpService:JSONDecode(response)
		return `{locationData["country"]} | {locationData["city"]}`
	else
		return "Failed to fetch data from API."
	end
end

function GameDataService:onInit()
	self.Proxy = Proxy(GameDataSchema)
	
	self.Proxy:Patch({
		{Name = "ChangeValue", Path = {"ServerRegion"}, Args = {GetRegionName()}}
	})

	self.Proxy:OnPatch(function(instructions)
		Crane:GetPacket("Patch").sendToAll({
			{},
			instructions,
		})
	end)
end

function GameDataService:onStart()
	self.ConfigService = Crane:GetService("ConfigService")

end

return GameDataService