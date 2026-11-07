const Debris = game:GetService("Debris")

--[=[
	Stand / aura.

	The aura belongs to the player, not the rig: the skin carries a template
	folder of emitters (`Assets.Stand.Aura`) and copies of it are instantiated on
	every limb of the OWNER character while the stand is summoned. Without the
	template the effect simply no-ops.
]=]

const Limbs = { "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "Torso" }

type StandAuraData = {
	Character: Model?,
	Aura: Instance?,
}

return {
	Auras = {},

	onStart = function(self, data: StandAuraData)
		local character, auraTemplate = data.Character, data.Aura
		if not (character and auraTemplate) then return end

		-- Summoning twice on one character must not stack a second copy of the aura.
		if self.Auras[character] ~= nil then return end

		const emitters = {}

		for _, limbName in Limbs do
			const limb = character:FindFirstChild(limbName)
			if limb == nil then continue end

			for _, template in auraTemplate:GetChildren() do
				const emitter = template:Clone()
				emitter.Parent = limb
				table.insert(emitters, emitter :: ParticleEmitter)
			end
		end

		self.Auras[character] = emitters

		character.Destroying:Once(function()
			self.Auras[character] = nil
		end)
	end,

	onStop = function(self, data: StandAuraData)
		local character = data.Character
		if character == nil then return end
		const emitters = self.Auras[character]
		self.Auras[character] = nil
		if emitters == nil then return end

		for _, emitter in emitters do
			emitter.Enabled = false
			Debris:AddItem(emitter, emitter.Lifetime.Max)
		end
	end,
}
