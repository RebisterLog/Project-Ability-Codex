const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ForgeVFX = require(ReplicatedStorage.shared.packages.ForgeVFX)
const LocalPlayer = Players.LocalPlayer
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const PlayerComponent = require(LocalPlayer.PlayerScripts.client.components.Player)
const Configuration = LocalPlayer.PlayerScripts.client.Configuration

const EffectsFolder = Configuration.EffectsFolder.Value

type Effect = {
	Validate: (self: Effect, data: any?) -> boolean,
	onStart: (self: Effect, data: any?) -> (),
	onStop: (self: Effect, data: any?) -> (),
}

const VFXService = Crane:CreateService({
	Name = "VFXService",
})
VFXService.Effects = {} :: { [string]: Effect }

function VFXService.onStart(self: typeof(VFXService))
	ForgeVFX.init()

	for i, module in EffectsFolder:QueryDescendants("ModuleScript") do
		self.Effects[module.Name] = require(module)
	end

	const StartVFXPacket = Crane:GetPacket("StartVFX")
	const StopVFXPacket = Crane:GetPacket("StopVFX")

	StartVFXPacket.listen(function(data: { name: string, args: { unknown } })
		self:StartEffect(data.name, data.args[1])
	end)

	StopVFXPacket.listen(function(data: { name: string, args: { unknown } })
		self:StopEffect(data.name, data.args[1])
	end)end

function VFXService:StartEffect(name: string, data: any?)
	if not self.Effects[name] then
		Crane.Utils.Log(script.Name, `Can't find VFX with name {name}`, "error")
		return
	end

	const effect: Effect = self.Effects[name]
	if effect.Validate and not effect:Validate(data) then return end

	effect:onStart(data)
end

function VFXService:StopEffect(name: string, data: any?)
	if not self.Effects[name] then
		Crane.Utils.Log(script.Name, `Can't find VFX with name {name}`, "error")
		return
	end

	const effect: Effect = self.Effects[name]
	if effect.onStop then effect:onStop(data) end
end

return VFXService
