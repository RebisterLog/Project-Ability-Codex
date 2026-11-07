const Debris = game:GetService("Debris")
const Lighting = game:GetService("Lighting")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const SoundService = game:GetService("SoundService")
const TweenService = game:GetService("TweenService")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const ForgeVFX = require(ReplicatedStorage.shared.packages.ForgeVFX)
const TimeStopZones = require(ReplicatedStorage.shared.effects.TimeStopZones)

--[=[ Time Stop.

   Four authored stages, mirroring the legacy client effect:

   Windup      highlights blink over the caster and the stand, a cast sound plays.
   Release     the "time stops" pulse: the bubble expands over the caster, the
               fog-like plume freezes in place (TimeScale = 0). Restores itself.
   ClientImpact the screen desaturates, the camera pulls out to FOV 50 with a
               shake, and a ticked loop rings until the freeze ends.
   End         cleanup assist: restores the fog emitters and plays the end sound.

   Every asset is optional and passed from the server, so this module never
   reaches into configs and no-ops cleanly when an asset is absent.
]=]

const BUBBLE_EXPAND_DURATION = 0.516
const BUBBLE_COLLAPSE_DELAY = 0.516
const BUBBLE_COLLAPSE_DURATION = 0.5
const STOP_SHAKE = "Explosion2"
const WINDUP_FADE = 0.6

type TimeStopData = {
	Type: "Windup" | "Release" | "ClientImpact" | "End",
	Character: Model?,
	Stand: Model?,
	Duration: number?,
	Radius: number?,
	HighlightTemplate: Instance?,
	StandHighlightTemplate: Instance?,
	CastSound: Sound?,
	EndSound: Sound?,
	BubbleTemplate: MeshPart?,
	SmoothTemplate: Attachment?,
	TSCCTemplate: ColorCorrectionEffect?,
	TickSound: Sound?,
}

const RunningEffects = {} :: { [Model]: { ColorCorrectionEffect? } }
const ActiveTicks = {} :: { [Model]: Sound? }

const function stopActive(character: Model?)
	if character == nil then return end
	RunningEffects[character] = nil

	const tick = ActiveTicks[character]
	ActiveTicks[character] = nil
	if tick ~= nil and tick.Parent ~= nil then tick:Destroy() end

	for _, effect in Lighting:GetChildren() do
		if effect:IsA("ColorCorrectionEffect") and effect.Name == "TS_CC" then effect:Destroy() end
	end
end

const function windup(character: Model, data: TimeStopData)
	const stand = data.Stand
	if stand == nil then return end

	const highlightTemplate = data.HighlightTemplate
	const standHighlightTemplate = data.StandHighlightTemplate
	if highlightTemplate ~= nil then
		const hl = highlightTemplate:Clone()
		hl.Parent = character
		ForgeVFX.emit(hl)
		Debris:AddItem(hl, WINDUP_FADE)
	end
	if standHighlightTemplate ~= nil then
		const hl2 = standHighlightTemplate:Clone()
		hl2.Parent = stand
		ForgeVFX.emit(hl2)
		Debris:AddItem(hl2, WINDUP_FADE)
	end

	const cast = data.CastSound
	if cast ~= nil then
		const sound = cast:Clone()
		sound.Parent = character:FindFirstChild("HumanoidRootPart") or character
		sound:Play()
		Debris:AddItem(sound, 5)
	end
end

const function release(character: Model, data: TimeStopData)
	const duration = data.Duration or 4
	const root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then return end

	-- Freeze the blast radius on every client: local simulations stand still
	-- while Time Stop is up.
	TimeStopZones.Register(root.CFrame.Position, data.Radius or 100, duration)

	const bubbleTemplate = data.BubbleTemplate
	if bubbleTemplate ~= nil then
		const bubble = bubbleTemplate:Clone() :: MeshPart
		bubble.Parent = workspace
		bubble:PivotTo(root.CFrame)
		TweenService:Create(
			bubble,
			TweenInfo.new(BUBBLE_EXPAND_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(120, 120, 120) }
		):Play()
		TweenService:Create(
			bubble,
			TweenInfo.new(BUBBLE_EXPAND_DURATION, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut),
			{ Transparency = 1 }
		):Play()

		task.delay(BUBBLE_COLLAPSE_DELAY, function()
			TweenService:Create(
				bubble,
				TweenInfo.new(BUBBLE_COLLAPSE_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.In),
				{ Size = Vector3.new(0.1, 0.1, 0.1) }
			):Play()
			TweenService:Create(
				bubble,
				TweenInfo.new(BUBBLE_COLLAPSE_DURATION, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
				{ Transparency = 10 }
			):Play()
			Debris:AddItem(bubble, BUBBLE_COLLAPSE_DURATION)
		end)
	end

	const smoothTemplate = data.SmoothTemplate
	if smoothTemplate ~= nil then
		const smooth = smoothTemplate:Clone()
		smooth.Parent = root
		ForgeVFX.emit(smooth)

		const emitters = {}
		for _, descendant in smooth:GetDescendants() do
			if descendant:IsA("ParticleEmitter") then table.insert(emitters, descendant) end
		end

		for _, emitter in emitters do
			TweenService:Create(
				emitter,
				TweenInfo.new(0.7, Enum.EasingStyle.Circular, Enum.EasingDirection.Out),
				{ TimeScale = 0 }
			):Play()
		end

		task.delay(duration, function()
			for _, emitter in emitters do
				TweenService:Create(emitter, TweenInfo.new(1), { TimeScale = 1 }):Play()
			end
		end)
		Debris:AddItem(smooth, duration + 5)
	end
end

const function clientImpact(character: Model, data: TimeStopData)
	const duration = data.Duration or 4

	const vfxService = Crane:GetService("VFXService")
	vfxService:StartEffect("CameraShake", { Type = STOP_SHAKE })

	const ccTemplate = data.TSCCTemplate
	if ccTemplate ~= nil then
		RunningEffects[character] = RunningEffects[character] or {}

		const cc = ccTemplate:Clone()
		cc.Name = "TS_CC"
		cc.Parent = Lighting
		table.insert(RunningEffects[character], cc)

		TweenService
			:Create(cc, TweenInfo.new(0.81, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Brightness = -0.1,
				Saturation = -1,
				TintColor = Color3.fromRGB(255, 255, 255),
			})
			:Play()
		TweenService:Create(
			cc,
			TweenInfo.new(0.81, Enum.EasingStyle.Circular, Enum.EasingDirection.Out),
			{ Contrast = -0.1 }
		):Play()

		-- Pull the camera to FOV fifty while time is frozen (legacy approach:
		-- drive through a Player-side `FOV` NumberValue).
		const fov = Instance.new("NumberValue")
		fov.Name = "FOV"
		fov.Parent = Players.LocalPlayer
		TweenService:Create(
			fov,
			TweenInfo.new(0.516, Enum.EasingStyle.Circular, Enum.EasingDirection.Out),
			{ Value = 50 }
		):Play()
		task.delay(0.516, function()
			TweenService:Create(
				fov,
				TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.In),
				{ Value = 0 }
			):Play()
			Debris:AddItem(fov, 0.5)
		end)

		task.delay(duration, function()
			TweenService:Create(cc, TweenInfo.new(0.83, Enum.EasingStyle.Linear), {
				Brightness = 0,
				Saturation = 0,
				Contrast = 0,
				TintColor = Color3.fromRGB(255, 255, 255),
			}):Play()
			Debris:AddItem(cc, 0.83)
		end)
	end

	const tick = data.TickSound
	if tick ~= nil then
		const sound = tick:Clone()
		sound.Parent = SoundService
		sound.Looped = true
		sound:Play()
		ActiveTicks[character] = sound
		task.delay(duration, function()
			TweenService:Create(sound, TweenInfo.new(1, Enum.EasingStyle.Linear), { Volume = 0 }):Play()
			Debris:AddItem(sound, 1)
			ActiveTicks[character] = nil
		end)
	end
end

const function onEnd(character: Model, data: TimeStopData)
	const endSound = data.EndSound
	if endSound ~= nil then
		const root = character:FindFirstChild("HumanoidRootPart")
		const sound = endSound:Clone()
		sound.Parent = root or character
		sound:Play()
		Debris:AddItem(sound, 5)
	end

	stopActive(character)
end

return {
	onStart = function(self, data: TimeStopData)
		if data == nil or typeof(data) ~= "table" or data.Character == nil then return end

		local character = data.Character

		if data.Type == "Windup" then
			windup(character, data)
		elseif data.Type == "Release" then
			release(character, data)
		elseif data.Type == "ClientImpact" then
			clientImpact(character, data)
		elseif data.Type == "End" then
			onEnd(character, data)
		end
	end,

	onStop = function(self, data: TimeStopData)
		stopActive(if data ~= nil then data.Character else nil)
	end,
}