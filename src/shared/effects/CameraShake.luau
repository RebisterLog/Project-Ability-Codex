const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

const Shake = require(ReplicatedStorage.shared.packages.ForgeVFX.pkg.Shake)

--[=[
	Camera shake for the local client.

	The server targets this effect at the caster only. The preset numbers are
	copied from the legacy `CameraShakePresets` table, where rotations are
	degrees; `Shake` hands back a raw vector, so the conversion happens here.
]=]

type Preset = {
	Amplitude: number,
	Frequency: number,
	FadeInTime: number,
	FadeOutTime: number,
	PositionInfluence: Vector3,
	RotationInfluence: Vector3,
}

--- `type` picks the preset, so the protocol is the preset name and nothing else.
type CameraShakeData = {
	Type: "Slam" | "Sendo" | "Explosion2" | "Sshot",
}

const PRESETS = {
	Slam = {
		Amplitude = 5,
		Frequency = 1 / 15,
		FadeInTime = 0,
		FadeOutTime = 0.6,
		PositionInfluence = Vector3.new(0.25, 0.25, 0.25),
		RotationInfluence = Vector3.new(4, 1, 1),
	},
	Sendo = {
		Amplitude = 4,
		Frequency = 1 / 10,
		FadeInTime = 0.2,
		FadeOutTime = 0.6,
		PositionInfluence = Vector3.new(0.25, 0.25, 0.25),
		RotationInfluence = Vector3.new(4, 1, 1),
	},
	Explosion2 = {
		Amplitude = 5,
		Frequency = 1 / 12,
		FadeInTime = 0,
		FadeOutTime = 0.75,
		PositionInfluence = Vector3.new(0.25, 0.25, 0.25),
		RotationInfluence = Vector3.new(4, 1, 1),
	},
	Sshot = {
		Amplitude = 3,
		Frequency = 1 / 8,
		FadeInTime = 0,
		FadeOutTime = 0.3,
		PositionInfluence = Vector3.new(0.25, 0.25, 0.25),
		RotationInfluence = Vector3.new(4, 1, 1),
	},
} :: { [string]: Preset }

const CAMERA_PRIORITY = Enum.RenderPriority.Camera.Value + 1

local ActiveShakes = 0
local StoredCFrame: CFrame? = nil
local RestoreConnection: RBXScriptConnection? = nil

const function restoreCamera()
	const camera = workspace.CurrentCamera
	const stored = StoredCFrame

	if stored ~= nil and camera.CameraType == Enum.CameraType.Custom then camera.CFrame = stored end

	StoredCFrame = nil

	if ActiveShakes == 0 and RestoreConnection ~= nil then
		RestoreConnection:Disconnect()
		RestoreConnection = nil
	end
end

const function applyShake(preset: Preset)
	const camera = workspace.CurrentCamera

	const shake = Shake.new()
	shake.Amplitude = preset.Amplitude
	shake.Frequency = preset.Frequency
	shake.FadeInTime = preset.FadeInTime
	shake.FadeOutTime = preset.FadeOutTime
	shake.PositionInfluence = preset.PositionInfluence
	shake.RotationInfluence = preset.RotationInfluence

	ActiveShakes += 1

	shake:BindToRenderStep(Shake.NextRenderName(), CAMERA_PRIORITY, function(pos, rot, isDone)
		if isDone then
			ActiveShakes -= 1
			return
		end

		if RestoreConnection == nil then
			RestoreConnection = RunService.Heartbeat:Connect(restoreCamera)
		end

		if StoredCFrame == nil then StoredCFrame = camera.CFrame end
		const base = StoredCFrame

		camera.CFrame = base
			* CFrame.new(pos)
			* CFrame.Angles(0, math.rad(rot.Y), 0)
			* CFrame.Angles(math.rad(rot.X), 0, math.rad(rot.Z))
	end)

	shake:Start()
end

return {
	onStart = function(self, data: CameraShakeData)
		const preset = PRESETS[data.Type]
		if preset == nil then return end

		applyShake(preset)
	end,
}