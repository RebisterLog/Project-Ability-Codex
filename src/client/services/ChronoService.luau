--!native
--!optimize 2

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Chrono = require(ReplicatedStorage.shared.packages.Chrono)
const LagCompensation = require(ReplicatedStorage.shared.combat.LagCompensation)

const ChronoService = Crane:CreateService({
	Name = "ChronoService",
	LoadOrder = -500,
})

function ChronoService:onInit()
	Chrono.Start(ReplicatedStorage.shared.configs.Chrono)
end

--- The exact server-timeline instants this client is currently rendering.
--- Both clocks exist because distant entities are half-ticked and are shown
--- one extra tick behind. The server picks the right one per target.
function ChronoService:GetAim(): LagCompensation.AimSample
	const config = Chrono.Config.GetEntityType("PLAYER")
	const clocks = config.CLIENT_CLOCK

	local normal = 0
	local half = 0
	if clocks and clocks.NORMAL then normal = clocks.NORMAL:GetTargetRenderTime() end
	if clocks and clocks.HALF then
		half = clocks.HALF:GetTargetRenderTime()
	else
		half = normal
	end

	return { Normal = normal, Half = half }
end

return ChronoService
