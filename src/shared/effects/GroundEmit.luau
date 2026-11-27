const Debris = game:GetService("Debris")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const FXUtil = require(ReplicatedStorage.shared.utility.FXUtil)

const Crane = require(ReplicatedStorage.shared.packages.Crane)
local VFXService = nil
task.spawn(function()
	while not Crane.IsStarted do
		task.wait(0.1)
	end
	VFXService = Crane:GetService("VFXService")
end)

const Params = RaycastParams.new()
Params.FilterDescendantsInstances = {workspace.Map}
Params.FilterType = Enum.RaycastFilterType.Include
Params.IgnoreWater = true

type ExtraEmitData = {
	Direction: Vector3?,
	Effect: string?,
	GroundOffset: CFrame?,
	Offset: CFrame?,
}

return {
	onStart = function(_self, data: ExtraEmitData)
		const Effect = data.Effect or "EmitParticle"
		const Offset = data.Offset or CFrame.identity
			
		local Origin = FXUtil.TranslateToCFrame(data.Origin)
		local GroundOffset = data.GroundOffset or CFrame.identity
		
		if not Origin then
			return
		end
		
		if Offset then
			Origin = Origin * Offset
		end
		
		const Direction = data.Direction or Vector3.new(0, -8, 0)
		local result = workspace:Raycast(Origin.Position, Direction, Params)
		if not result then return end
		
		VFXService:StartEffect(Effect, Crane.Utils.Reconcile({
			Origin = result.Position + result.Normal * 0.125,
			Offset = GroundOffset
		}, data))
	end,
}
