const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const LocalPlayer = Players.LocalPlayer
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)
const PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
const GameData = require(ReplicatedStorage.shared.schemas.GameData)

const Player = Crane:CreateComponent({
	Name = "Player",
} :: Crane.ComponentDef<Player>)

type PlayerModuleHost = {
	GetModule: (self: PlayerModuleHost, name: string) -> ClientPlayerModule?,
}

export type ClientPlayerModule = {
	Name: string,
	player: PlayerModuleHost,
	playerProxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	gameProxy: Proxy.ProxyTab<GameData.GameData>,
	Cleaner: typeof(Crane.Buttler.new()),
	onInit: ((self: ClientPlayerModule) -> ())?,
	onStart: ((self: ClientPlayerModule) -> ())?,
	onCharacter: ((self: ClientPlayerModule, character: Model) -> ())?,
	onDestroy: ((self: ClientPlayerModule) -> ())?,
}

function Player.onStart(self: typeof(Player))
	self.Modules = {}
	self.Cleaner = Crane.Buttler.new()
	self.CharacterModel = nil
	self.ModulesReady = false

	self.Cleaner:Connect(self.instance.CharacterAdded, function(character: Model)
		self:AttachCharacter(character)
	end)

	if self.instance.Character then self:AttachCharacter(self.instance.Character) end
end

function Player:AttachCharacter(character: Model)
	if self.Character then self.Character:Destroy() end

	self.Character = Crane:AddComponent(character, "Character")
	self:OnCharacter(character)
end

function Player:OnCharacter(character: Model)
	self.CharacterModel = character

	if not self.ModulesReady then return end

	for name, module in self.Modules do
		const callback = module.onCharacter
		if not callback then continue end

		const ok, err = pcall(callback, module, character)
		if not ok then warn(`[Player] onCharacter failed in module "{name}": {err}`) end
	end
end

function Player.GetModule(self: typeof(Player), name: string): ClientPlayerModule?
	return self.Modules[name]
end

function Player.InitModules(
	self: typeof(Player),
	playerProxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	gameProxy: Proxy.ProxyTab<GameData.GameData>
)
	const folder = LocalPlayer.PlayerScripts.client["player-modules"]
	if not folder then
		warn("[Player] player-modules folder is missing")
		return
	end

	for _, instance in folder:GetDescendants() do
		if not instance:IsA("ModuleScript") then continue end

		const content = Crane.Utils.DeepClone(require(instance)) :: ClientPlayerModule
		content.Name = instance.Name
		content.player = self
		content.playerProxy = playerProxy
		content.gameProxy = gameProxy
		content.Cleaner = self.Cleaner:Scope()
		self.Modules[content.Name] = content
	end

	for name, module in self.Modules do
		if not module.onInit then continue end

		const ok, err = pcall(module.onInit, module)
		if not ok then warn(`[Player] onInit failed in module "{name}": {err}`) end
	end

	for name, module in self.Modules do
		if not module.onStart then continue end

		const ok, err = pcall(module.onStart, module)
		if not ok then warn(`[Player] onStart failed in module "{name}": {err}`) end
	end

	self.ModulesReady = true

	if self.CharacterModel then self:OnCharacter(self.CharacterModel) end
end

function Player.Destroy(self: typeof(Player))
	if self.Modules then
		for name, module in self.Modules do
			if module.onDestroy then
				const ok, err = pcall(module.onDestroy, module)
				if not ok then warn(`[Player] onDestroy failed in module "{name}": {err}`) end
			end

			module.Cleaner:Destroy()
		end
	end

	if self.Cleaner then self.Cleaner:Destroy() end
end

return Player
