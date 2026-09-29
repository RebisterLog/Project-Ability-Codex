local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")

local Crane = require(ReplicatedStorage.shared.packages.Crane)
local PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
local Proxy = require(ReplicatedStorage.shared.packages.Proxy)
local PlayerSaveData = require(ReplicatedStorage.shared.schemas.PlayerSaveData)
local DraftController = require(ReplicatedStorage.shared.packages.DraftController)

local Configuration = ServerScriptService.server.Configuration

type PlayerComponentData = {
	Proxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	Modules: {[string]: PlayerModule},
	Janitor: typeof(Crane.Janitor.new()),
}

local Player: Crane.Component<Player> & PlayerComponentData = Crane:CreateComponent({
	Name = "Player",
}:: Crane.ComponentDef<Player>)

export type PlayerModule = {
	Name: string,
	player: typeof(Player),
	playerProxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	onInit: (self: PlayerModule) -> (),
	onStart: (self: PlayerModule) -> (),
}

function Player.onStart(self: typeof(Player))
	self.Modules = {}
	self.Janitor = Crane.Janitor.new()

	--local point = CollectionService:GetTagged("Lobby")[1] :: SpawnLocation
	--self.instance.RespawnLocation = point
end

function Player:SetSpec(abilityName: string)
	
end

function Player.Destroy(self: typeof(Player))
	self.Janitor:Cleanup()
end

function Player.LoadDocumentData(self: typeof(Player), data: PlayerSaveData.PlayerSaveData)
	self.Proxy = Proxy(DraftController.merge(PlayerData, data))

	self.Proxy:OnPatch(function(instructions)
		Crane:GetPacket("Patch").sendTo({
			instructions,
			{},
		}, self.instance)
	end)

	self:InitModules()
end

function Player.GetModule(self: typeof(Player), name: string)
	return self.Modules[name]
end

function Player.InitModules(self: typeof(Player))
	for i, module in Configuration.PlayerModulesFolder.Value:QueryDescendants("ModuleScript") do
		local content = Crane.Utils.DeepClone(require(module)) :: PlayerModule
		content["Name"] = module.Name
		content["player"] = self
		content["playerProxy"] = self.Proxy
		self.Modules[content.Name] = content
	end

	for name, module in self.Modules do
		if not module.onInit then continue end
		module:onInit()
	end

	for name, module in self.Modules do
		if not module.onStart then continue end
		module:onStart()
	end
end

return Player
