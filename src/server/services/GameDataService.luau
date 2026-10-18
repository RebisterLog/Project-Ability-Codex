const HttpService = game:GetService("HttpService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

const Proxy = require(ReplicatedStorage.shared.packages.Proxy)

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const GameDataSchema = require(ReplicatedStorage.shared.schemas.GameData)

const GameDataService = Crane:CreateService({
	Name = "GameDataService",
	LoadOrder = -100,
})

const url = "https://ipconfig.io/json"
const GetRegionName = function(): string
	const response = HttpService:GetAsync(url, false) -- get the data from the API

	if response then -- if the data from API is successfully retrieved and is not nil
		const locationData = HttpService:JSONDecode(response)
		return `{locationData["country"]} | {locationData["city"]}`
	else
		return "Failed to fetch data from API."
	end
end

function GameDataService:onInit()
	self.Proxy = Proxy(GameDataSchema)

	self.Proxy:Patch({
		{ Name = "ChangeValue", Path = { "ServerRegion" }, Args = { GetRegionName() } },
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
