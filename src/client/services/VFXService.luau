local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local PlayerComponent = require(LocalPlayer.PlayerScripts.client.components.Player)
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local Configuration = LocalPlayer.PlayerScripts.client.Configuration

local EffectsFolder = Configuration.EffectsFolder.Value

type Effect = {
	Validate: (self: Effect, ...any) -> boolean,
	onStart: (self: Effect, ...any) -> (),
	onStop: (self: Effect, ...any) -> (),
}

local VFXService = Crane:CreateService({
	Name = "VFXService",
})
VFXService.Effects = {} :: {[string]: Effect}

function VFXService.onStart(self: typeof(VFXService))
	for i, module in EffectsFolder:QueryDescendants("ModuleScript") do
		self.Effects[module.Name] = require(module)
	end

	local StartVFXPacket = Crane:GetPacket("StartVFX")
	local StopVFXPacket = Crane:GetPacket("StopVFX")

	StartVFXPacket.listen(function(data: {name: string, args: {unknown}})
		self:StartEffect(data.name, table.unpack(data.args))
	end)

	StopVFXPacket.listen(function(data: {name: string, args: {unknown}})
		self:StopEffect(data.name, table.unpack(data.args))
	end)
end

function VFXService:StartEffect(name: string, ...)
	if not self.Effects[name] then
		Crane.Utils.Log(script.Name, `Can't find VFX with name {name}`, "error")
		return
	end

	local effect: Effect = self.Effects[name]
	if effect.Validate and not effect:Validate(...) then return end

	effect:onStart(...)
end

function VFXService:StopEffect(name: string, ...)
	if not self.Effects[name] then
		Crane.Utils.Log(script.Name, `Can't find VFX with name {name}`, "error")
		return
	end

	local effect: Effect = self.Effects[name]
	if effect.onStart then effect:onStop(...) end
end

return VFXService
