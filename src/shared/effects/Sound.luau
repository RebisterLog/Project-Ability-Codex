const ReplicatedStorage = game:GetService("ReplicatedStorage")
const TweenService = game:GetService("TweenService")

type SoundData = {
	Origin: CFrame | Instance,
	Sound: Sound?,
	Volume: number?,
	MaxDistance: number?,
	MinDistance: number?,
}

type SoundStopData = {
	Origin: Instance?,
	Sound: Sound?,
}

return {
	Validate = function(self, data: SoundData)
		-- 		const Origin = data.Origin
		-- 		if Origin == nil then return false end
		--
		-- 		const pos = typeof(Origin) == "CFrame" and Origin.Position or Origin.Position
		-- 		const maxDistance = data.MaxDistance or 100
		-- 		if (pos - workspace.CurrentCamera.CFrame.Position).Magnitude > maxDistance then
		-- 			return false
		-- 		end
		return true
	end,

	onStart = function(self, data: SoundData)
		local SoundTemplate = data.Sound
		local Origin = data.Origin

		local volume = data.Volume
		if typeof(SoundTemplate) == "table" then
			volume = volume or SoundTemplate.Volume
			SoundTemplate = SoundTemplate.Sound
		end

		if not (SoundTemplate and Origin) then return end
		if typeof(SoundTemplate) ~= "Instance" or not SoundTemplate:IsA("Sound") then return end

		const Sound = SoundTemplate:Clone()

		Sound.RollOffMaxDistance = data.MaxDistance or 100
		Sound.RollOffMinDistance = data.MinDistance or 10
		Sound.Volume = volume or 1

		if typeof(Origin) == "CFrame" then
			const Attachment = Instance.new("Attachment")
			Attachment.WorldCFrame = Origin
			Attachment.Parent = workspace.Terrain
			Sound.Parent = Attachment
			Sound:Play()
			task.delay(Sound.TimeLength + 1, function()
				Attachment:Destroy()
			end)
			return
		end

		if typeof(Origin) == "Instance" then
			Sound.Parent = Origin
			Sound:Play()
			task.delay(Sound.TimeLength + 1, function()
				Sound:Destroy()
			end)
		end
	end,
	onStop = function(self, data: SoundStopData)
		local Inst = data.Origin
		local Sound = data.Sound

		if typeof(Sound) == "table" then
			Sound = Sound.Sound
		end

		if not (Inst and Sound) then return end
		if typeof(Sound) ~= "Instance" then return end
		local playing = Inst:FindFirstChild(Sound.Name)
		if playing then playing:Destroy() end
	end,
}
