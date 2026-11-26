const Debris = game:GetService("Debris")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const TweenService = game:GetService("TweenService")
const ForgeVFX = require(ReplicatedStorage.shared.packages.ForgeVFX)

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
		const Origin = Data.Origin
		const Offset = Data.Offset or CFrame.identity
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

		if originPart then
			if Particle:IsA("BasePart") then
				const weld = Instance.new("Weld")
				weld.Part0 = originPart
				weld.Part1 = Particle
				weld.C0 = Offset
				weld.Parent = Particle
			else
				-- Attachments and Folders cannot be welded directly. Give them
				-- an invisible Part anchor instead and weld that to the origin.
				const anchor = Instance.new("Part")
				anchor.Size = Vector3.new(1, 1, 1)
				anchor.CFrame = originPart.CFrame * Offset
				prepareParticle(anchor)

				const weld = Instance.new("Weld")
				weld.Part0 = originPart
				weld.Part1 = anchor
				weld.Parent = anchor

				Particle.Parent = anchor
				for _, part in Particle:GetDescendants() do
					if part:IsA("BasePart") then
						const inner = Instance.new("Weld")
						inner.Part0 = anchor
						inner.Part1 = part
						inner.Parent = part
					end
				end
				container = anchor
			end
		elseif Particle:IsA("BasePart") then
			Particle.CFrame = anchorCFrame(Origin, Offset)
			Particle.Anchored = true
		else
			const anchor = Instance.new("Part")
			anchor.Size = Vector3.new(1, 1, 1)
			anchor.CFrame = anchorCFrame(Origin, Offset)
			anchor.Anchored = true
			prepareParticle(anchor)

			Particle.Parent = anchor
			for _, part in Particle:GetDescendants() do
				if part:IsA("BasePart") then part.Anchored = true end
			end
			container = anchor
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
