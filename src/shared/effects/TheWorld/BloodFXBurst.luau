const ReplicatedStorage = game:GetService("ReplicatedStorage")
const BloodFX = require(ReplicatedStorage.shared.packages.BloodFX)

const Emitters: { [string]: any } = {}

type BloodData = {
	Character: Model?,
	Limb: string?,
	Preset: string?,
	UUID: string?,
}

return {
	onStart = function(_, data: BloodData)
		const uuid = data.UUID or "bloodfx-default"
		if Emitters[uuid] then return end

		const character = data.Character
		const origin = character and character:FindFirstChild(data.Limb or "")
		if not origin or not origin:IsA("BasePart") then
			const root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				pcall(function()
					BloodFX.spray(root.Position, Vector3.new(0, 1, 0), "Burst")
				end)
			end
			return
		end

		pcall(function()
			Emitters[uuid] = BloodFX.emitter(origin, "Fountain", { beats = 2 })
		end)
	end,

	onStop = function(_, data: { UUID: string? })
		const uuid = data.UUID or "bloodfx-default"
		const emitter = Emitters[uuid]
		if emitter then
			pcall(function()
				emitter:destroy()
			end)
			Emitters[uuid] = nil
		end
	end,
}
