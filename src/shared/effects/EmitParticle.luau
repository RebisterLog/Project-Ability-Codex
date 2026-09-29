local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local ForgeVFX = require(ReplicatedStorage.shared.packages.ForgeVFX)

type EmitData = {
	UUID: number,
	Particle: BasePart,
	Origin: CFrame | Instance,
	Offset: CFrame?,
	UseForge: boolean?,
}

local Particles = {}

@native
local function prepareParticle(paricle: BasePart)
	paricle.Anchored = false
	paricle.CanCollide = false
	paricle.CanQuery = false
	paricle.CastShadow = false
	paricle.Massless = true
	paricle.Transparency = 1
end

return {
	onStart = function(self, Data: EmitData)
		local Particle = Data.Particle:Clone()
		local Origin = Data.Origin
		local Offset = Data.Offset
		local UseForge = Data.UseForge
		
		prepareParticle(Particle)
		
		if typeof(Origin) == "Instance" then
			local weld = Instance.new("Weld")
			weld.Part0 = Origin
			weld.Part1 = Particle
			weld.Parent = Particle
			weld.C0 = Offset or CFrame.identity
		else
			Particle.Anchored = true
		end
		
		if Offset and Origin and typeof(Origin) == "CFrame" then
			Origin *= Offset
			Particle:PivotTo(Origin)
		end
		
		if not (Particle and Origin) then
			return
		end
		
		Particle.Parent = workspace.Effects
		
		if Data.UUID then
			Particles[Data.UUID] = Particle
		end
		
		if UseForge then
			ForgeVFX.emit(Particle).Finished:andThen(function()
				Debris:AddItem(Particle)
			end)
			
			return
		end
		
		local MaxLifetime = 0
		
		for _, ParticleEmitter in Particle:QueryDescendants("ParticleEmitter") do
			local EmitCount = ParticleEmitter:GetAttribute("EmitCount") or 0
			local EmitDelay = ParticleEmitter:GetAttribute("EmitDelay") or 0
			local EmitEnable = ParticleEmitter:GetAttribute("EmitEnable") or false
			
			if ParticleEmitter.Lifetime.Max > MaxLifetime then
				MaxLifetime = ParticleEmitter.Lifetime.Max
			end
			
			task.delay(EmitDelay, function()
				if EmitEnable then
					ParticleEmitter.Enabled = true
				else
					ParticleEmitter:Emit(EmitCount)
				end
			end)
		end
		
		task.delay(MaxLifetime, function()
			for _, ParticleEmitter in Particle:QueryDescendants("ParticleEmitter") do
				ParticleEmitter.Enabled = false
			end
		end)
		
		Debris:AddItem(Particle, MaxLifetime + 3)
	end,
	
	onStop = function(self, uuid: number)
		if Particles[uuid] then
			Particles[uuid]:Destroy()
		end
	end,
}