local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

type SoundData = {
	Sound: Sound,
	Volume: number?,
	MaxDistance: number?,
	MinDistance: number?,
}

return {
	Validate = function(self, Origin: CFrame | Instance, SoundData: SoundData)
		local pos = typeof(Origin) == "CFrame" and Origin.Position or Origin.Position
		if (pos - workspace.CurrentCamera.CFrame.Position).Magnitude > (SoundData.MaxDistance and SoundData.MaxDistance or 100) then return false end
		return true
	end,
	
	onStart = function(self, Origin: CFrame | Instance, SoundData: SoundData)
		if not SoundData then
			return
		end
		
		local Sound = SoundData.Sound
		
		if not (Sound and Sound.Parent and Origin) then
			return
		end		
		
		Sound = Sound:Clone()
		
		Sound.RollOffMaxDistance = SoundData.MaxDistance or 100
		Sound.RollOffMinDistance = SoundData.MinDistance or 10
		Sound.Volume = SoundData.Volume or 1
		
		if typeof(Origin) == "CFrame" then
			local Attachment = Instance.new("Attachment")
			Attachment.WorldCFrame = Origin
			Attachment.Parent = workspace.Terrain
			Sound.Parent = Attachment
			task.delay(Sound.TimeLength + 1, Attachment.Destroy, Attachment)
		end
		
		if typeof(Origin) == "Instance" then
			Sound.Parent = Origin
		end
		
		Sound:Play()
		
		task.delay(Sound.TimeLength + 1, function()
			Sound:Destroy()
		end)
	end,
	onStop = function(self, Inst: Instance, Sound: Sound)
		if not (Inst and Sound) then
			return
		end
		if Inst:FindFirstChild(Sound.Name) then
			Inst[Sound.Name]:Destroy()
		end
	end,
}	