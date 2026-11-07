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

		if not (SoundTemplate and Origin and SoundTemplate.Parent) then return end

		const Sound = SoundTemplate:Clone()

		Sound.RollOffMaxDistance = data.MaxDistance or 100
		Sound.RollOffMinDistance = data.MinDistance or 10
		Sound.Volume = data.Volume or 1

		if typeof(Origin) == "CFrame" then
			const Attachment = Instance.new("Attachment")
			Attachment.WorldCFrame = Origin
			Attachment.Parent = workspace.Terrain
			Sound.Parent = Attachment
			task.delay(Sound.TimeLength + 1, Attachment.Destroy, Attachment)
		end

		if typeof(Origin) == "Instance" then Sound.Parent = Origin end

		Sound:Play()

		task.delay(Sound.TimeLength + 1, function()
			Sound:Destroy()
		end)
	end,
	onStop = function(self, data: SoundStopData)
		local Inst = data.Origin
		local Sound = data.Sound

		if not (Inst and Sound) then return end
		if Inst:FindFirstChild(Sound.Name) then Inst[Sound.Name]:Destroy() end
	end,
}
