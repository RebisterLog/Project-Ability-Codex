const Debris = game:GetService("Debris")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ForgeVFX = require(ReplicatedStorage.shared.packages.ForgeVFX)

const LIFETIME = 3

type HitFeedbackData = {
	Character: Model,
	Effects: Folder?,
	Sound: Sound?,
}

return {
	onStart = function(_self, data: HitFeedbackData)
		const character = data.Character
		if not character:IsDescendantOf(workspace) then return end

		const torso = character:FindFirstChild("Torso")
		if not torso then return end

		if data.Effects then
			for _, child in data.Effects:GetChildren() do
				const clone = child:Clone()
				clone.Parent = torso
				ForgeVFX.emit(clone)
				Debris:AddItem(clone, LIFETIME)
			end
		end

		if data.Sound then
			const sound = data.Sound:Clone()
			sound.Parent = torso
			-- The one-shot trick: play on removal, then remove.
			sound.PlayOnRemove = true
			sound:Destroy()
		end
	end,
}
