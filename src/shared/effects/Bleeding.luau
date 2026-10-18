const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Assets = ReplicatedStorage.assets.Default
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const ForgeVFX = require(ReplicatedStorage.shared.packages.ForgeVFX)

const Cleaners = {}

return {
	onStart = function(self, character: Model)
		if Cleaners[character] then return end
		if not character:IsDescendantOf(workspace) then return end

		const RootPart = character:FindFirstChild("HumanoidRootPart")
		if not RootPart then return end

		const cleaner = Crane.Buttler.new()

		-- The wound is the same part for everyone, held on the character for as
		-- long as the bleed lives: `Assets.Default.Bleeding` is anchored in the
		-- folder, so the clone has to be released before it is welded.
		const Effect = cleaner:Clone(Assets.Bleeding) :: BasePart

		const weld = cleaner:Construct(Instance, "Weld") :: Weld
		weld.Part0 = RootPart
		weld.Part1 = Effect
		weld.C0 = Effect:GetAttribute("Offset") or CFrame.new(0, 0.5, 0)
		weld.Parent = Effect

		Effect.Anchored = false
		Effect.Parent = workspace.Effects

		-- ForgeVFX owns the emission: the burst of `EmitCount` and the window
		-- of `EmitDuration`. Its Clear stops both mid-flight, so a bleed that
		-- ends early does not leave the wound spraying blood.
		cleaner:Add(ForgeVFX.emit(Effect).Clear)

		-- A character removed while bleeding takes the wound with it; the cache
		-- entry goes with the model so a respawn starts from a clean slate.
		cleaner:LinkToInstance(character)
		character.Destroying:Once(function()
			Cleaners[character] = nil
		end)

		Cleaners[character] = cleaner
	end,

	onStop = function(self, character: Model)
		const cleaner = Cleaners[character]
		if not cleaner then return end

		Cleaners[character] = nil
		cleaner:Destroy()
	end,
}
