--!native
--!optimize 2

const Debris = game:GetService("Debris")
const TweenService = game:GetService("TweenService")

--[=[
	Burning.

	State effect of the `Burning` parameter: the character's `Burning` watcher
	opens it when the meter gains a burn and closes it when the burn runs out, so
	the flames can never outlive the state.

	A flame emitter cloned onto every limb, the ignition sound and a looping fire
	sound on the root, plus a point light tweened to range 12 / brightness 0.5 over
	a second. On the way out every emitter is switched off and asked for one last
	burst of `EmitCount` particles, the sounds fade their volume to zero and the
	light goes back to range 6 / brightness 0, all cleared two seconds later.

	ASSETS (optional, the effect no-ops without the rig):

	`ReplicatedStorage.assets.Default.Combat.Burning`
		Flame: ParticleEmitter, BurnLight: PointLight, Burning: Sound,
		EnchantFlame: Sound
]=]

const Limbs = { "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "Torso" }

const BURN_TWEEN = TweenInfo.new(1)
const CLEAR_AFTER = 2

const BURN_ON = { Range = 12, Brightness = 0.5 }
const BURN_OFF = { Range = 6, Brightness = 0 }

type BurningData = {
	Character: Model?,
	-- `ReplicatedStorage.assets.Default.Combat.Burning`, passed by the watcher
	-- that owns the state.
	Rig: Folder?,
}

return {
	Burns = {},

	onStart = function(self, data: BurningData)
		const character, rig = data.Character, data.Rig
		if not (character and rig) then return end

		const root = character:FindFirstChild("HumanoidRootPart")
		if root == nil then return end

		self:StopFor(character)

		const parts = {}

		const flame = rig:FindFirstChild("Flame")
		if flame ~= nil then
			for _, limbName in Limbs do
				const limb = character:FindFirstChild(limbName)
				if limb == nil then continue end

				const emitter = flame:Clone() :: ParticleEmitter
				emitter.Parent = limb
				table.insert(parts, emitter)
			end
		end

		const ignite = rig:FindFirstChild("EnchantFlame")
		if ignite ~= nil then
			const sound = ignite:Clone() :: Sound
			sound.Parent = root
			-- The one-shot trick: play on removal, then remove.
			sound.PlayOnRemove = true
			sound:Destroy()
		end

		const burning = rig:FindFirstChild("Burning")
		if burning ~= nil then
			const sound = burning:Clone() :: Sound
			sound.Parent = root
			table.insert(parts, sound)
			sound:Play()
		end

		const light = rig:FindFirstChild("BurnLight")
		if light ~= nil then
			const burnLight = light:Clone() :: PointLight
			burnLight.Parent = root
			table.insert(parts, burnLight)
			TweenService:Create(burnLight, BURN_TWEEN, BURN_ON):Play()
		end

		self.Burns[character] = parts

		character.Destroying:Once(function()
			self:StopFor(character)
		end)
	end,

	StopFor = function(self, character: Model)
		const parts = self.Burns[character]
		self.Burns[character] = nil
		if parts == nil then return end

		for _, part in parts do
			if part:IsA("ParticleEmitter") then
				const emitter = part :: ParticleEmitter
				emitter.Enabled = false
				emitter:Emit(emitter:GetAttribute("EmitCount") or 0)
			elseif part:IsA("Sound") then
				TweenService:Create(part :: Sound, BURN_TWEEN, { Volume = 0 }):Play()
			else
				TweenService:Create(part :: PointLight, BURN_TWEEN, BURN_OFF):Play()
			end

			Debris:AddItem(part, CLEAR_AFTER)
		end
	end,

	onStop = function(self, data: BurningData)
		if data.Character == nil then return end
		self:StopFor(data.Character)
	end,
}
