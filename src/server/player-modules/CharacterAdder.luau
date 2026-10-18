const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)
const types = require(ServerScriptService.server.types)

const CharacterAdder = {} :: types.PlayerModule

function CharacterAdder.Spawn(self: typeof(CharacterAdder))
	if not table.find(Players:GetPlayers(), self.player.instance) then return end
	self.player.instance:LoadCharacterAsync()
end

function CharacterAdder.onCharacterAdded(self: typeof(CharacterAdder), character: Model)
	self.Character = Crane:AddComponent(character, "Character")

	self.Character.Destroying:Once(function()
		self:Spawn()
	end)

	Crane:GetService("CollisionService"):SetCollisionGroup("Player", character)
	self.player.Modules["SpecModule"]:SetSpec(self.player.Modules["SpecModule"]:GetSpec())
	self.player.Modules["GodModeModule"]:OnCharacter(self.Character)
	self.player.Modules["NoCooldownModule"]:OnCharacter(self.Character)
end

function CharacterAdder.onStart(self: typeof(CharacterAdder))
	self.player.instance.CharacterAdded:Connect(function(character)
		self:onCharacterAdded(character)
	end)

	if self.player.instance.Character then self:onCharacterAdded(self.player.instance.Character) end

	self:Spawn()
end

return CharacterAdder
