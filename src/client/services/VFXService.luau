const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ForgeVFX = require(ReplicatedStorage.shared.packages.ForgeVFX)
const LocalPlayer = Players.LocalPlayer
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const PlayerComponent = require(LocalPlayer.PlayerScripts.client.components.Player)
const Configuration = LocalPlayer.PlayerScripts.client.Configuration

const EffectsFolder = ReplicatedStorage.shared.effects

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
	end)
end

-- Effects are registered at onStart, but Rojo can sync a new effect module a
-- little later than the service boots. Resolve it on demand instead of losing
-- the packet entirely.
const function resolveEffect(self: typeof(VFXService), name: string): Effect?
	if self.Effects[name] then return self.Effects[name] end

	for _, module in EffectsFolder:QueryDescendants("ModuleScript") do
		if module.Name ~= name then continue end
		const effect = require(module) :: Effect
		self.Effects[name] = effect
		return effect
	end
	return nil
end

function VFXService:StartEffect(name: string, data: any?)
	const effect = resolveEffect(self, name)
	if not effect then
		Crane.Utils.Log(script.Name, `Can't find VFX with name {name}`, "error")
		return
	end

	if effect.Validate and not effect:Validate(data) then return end

	effect:onStart(data)
end

function VFXService:StopEffect(name: string, data: any?)
	const effect = resolveEffect(self, name)
	if not effect then
		Crane.Utils.Log(script.Name, `Can't find VFX with name {name}`, "error")
		return
	end

	if effect.onStop then effect:onStop(data) end
end

return VFXService
