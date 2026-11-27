const Debris = game:GetService("Debris")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const TweenService = game:GetService("TweenService")
const ForgeVFX = require(ReplicatedStorage.shared.packages.ForgeVFX)
const FXUtil = require(ReplicatedStorage.shared.utility.FXUtil)

type EmitData = {
	UUID: number?,
	-- Templates are not guaranteed to be BaseParts: hit feedback uses an
	-- Attachment (BaseHitVFX) and Leg Barrage uses a Folder of VFX parts.
	Particle: Instance?,
	Origin: CFrame | Instance,
	Offset: CFrame?,
	UseForge: boolean?,
}

const Particles = {}

@native
local function prepareParticle(object: Instance)
	if object:IsA("BasePart") then
		object.Anchored = false
		object.CanCollide = false
		object.CanQuery = false
		object.CastShadow = false
		object.Massless = true
		object.Transparency = 1
	elseif object:IsA("Decal") then
		object.Transparency = 1
	end
end

const function anchorCFrame(origin: CFrame | Instance, offset: CFrame): CFrame
	if typeof(origin) == "CFrame" then return origin * offset end
	if origin:IsA("BasePart") then return origin.CFrame * offset end
	if origin:IsA("Attachment") then return origin.WorldCFrame * offset end
	return offset
end

return {
	onStart = function(self, Data: EmitData)
		const template = Data.Particle
		if not template then return end

		const Particle = template:Clone()
		local Origin = FXUtil.TranslateToCFrame(Data.Origin)
		const Offset = FXUtil.TranslateToCFrame(Data.Offset)
		const UseForge = Data.UseForge

		prepareParticle(Particle)
		for _, object in Particle:GetDescendants() do
			prepareParticle(object)
		end

		const originInstance = if typeof(Origin) == "Instance" then Origin else nil
		const originPart = if originInstance and originInstance:IsA("BasePart")
			then originInstance
			else nil

		local container: Instance = Particle
		
		if Offset and typeof(Offset) == "CFrame" then
			Origin *= Offset
		end
		
		if Data.AttachTo then
			FXUtil.AttachTo(Particle, Data.AttachTo)
		else
			FXUtil.MoveTo(Particle, Origin)
		end

		container.Parent = workspace.Effects
		if Data.UUID then Particles[Data.UUID] = container end

		if UseForge then
			ForgeVFX.emit(container).Finished:andThen(function()
				Debris:AddItem(container)
			end)
			return
		end

		local MaxLifetime = 0
		for _, emitter in Particle:QueryDescendants("ParticleEmitter") do
			const emitCount = emitter:GetAttribute("EmitCount") or 0
			const emitDelay = emitter:GetAttribute("EmitDelay") or 0
			const emitEnable = emitter:GetAttribute("EmitEnable") or false

			if emitter.Lifetime.Max > MaxLifetime then MaxLifetime = emitter.Lifetime.Max end

			task.delay(emitDelay, function()
				if emitEnable then
					emitter.Enabled = true
				else
					emitter:Emit(emitCount)
				end
			end)
		end

		task.delay(MaxLifetime, function()
			for _, emitter in Particle:QueryDescendants("ParticleEmitter") do
				emitter.Enabled = false
			end
		end)

		Debris:AddItem(container, MaxLifetime + 3)
	end,

	onStop = function(self, data: EmitStopData)
		if not data.UUID then return end
		const particle = Particles[data.UUID]
		if particle then particle:Destroy() end
		Particles[data.UUID] = nil
	end,
}
