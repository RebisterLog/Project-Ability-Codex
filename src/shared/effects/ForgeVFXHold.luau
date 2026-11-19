--[=[ ForgeVFXHold

   Client-side holder for a skill-long VFX. ForgeVFX is client-only, so the
   server sends StartVFX/StopVFX with a UUID. Emission is owned by ForgeVFX:
   `ForgeVFX.enable` turns the cloned emitters on for the whole skill and
   `ForgeVFX.disable` turns them off when it ends.

   Start: { UUID, Template: BasePart, Origin: Instance, Offset: CFrame? }
   Stop:  { UUID }
]=]

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const ForgeVFX = require(ReplicatedStorage.shared.packages.ForgeVFX)

type Key = number | string

type Data = {
	UUID: Key,
	Template: BasePart?,
	Origin: Instance?,
	Offset: CFrame?,
}

const Active: { [Key]: any } = {}

return {
	Validate = function(_self, data: Data)
		return data ~= nil and data.UUID ~= nil and data.Template ~= nil
	end,

	onStart = function(_self, data: Data)
		const template = data.Template
		if not template then return end

		const previous = Active[data.UUID]
		if previous then
			Active[data.UUID] = nil
			previous:Destroy()
		end

		const cleaner = Crane.Buttler.new()
		const effect = cleaner:Clone(template) :: BasePart

		for _, part in effect:GetDescendants() do
			if not part:IsA("BasePart") then continue end

			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = false
			part.Massless = true
			part.Transparency = 1
		end

		const origin = data.Origin
		if origin and origin:IsA("BasePart") then
			const weld = cleaner:Construct(Instance, "Weld") :: Weld
			weld.Part0 = origin
			weld.Part1 = effect
			weld.C0 = data.Offset or CFrame.identity
			weld.Parent = effect
		else
			effect.Anchored = true
		end

		-- Forge needs the clone inside the DataModel before it emits: otherwise
		-- it clones the emitter ancestry into Terrain instead of using this part.
		effect.Parent = workspace.Effects

		-- ForgeVFX owns emission: enable for the skill, disable on stop.
		-- `Clear` is ForgeVFX's stop button for anything emitted with a burst
		-- or an EmitDuration, and it wipes particles already in flight.
		cleaner:Add(function()
			ForgeVFX.disable(effect)
		end)
		cleaner:Add(ForgeVFX.emit(effect).Clear)
		ForgeVFX.enable(effect)

		if origin then cleaner:LinkToInstance(origin) end

		Active[data.UUID] = cleaner
	end,

	onStop = function(_self, data: { UUID: Key? })
		if data.UUID == nil then return end

		const cleaner = Active[data.UUID]
		if not cleaner then return end

		Active[data.UUID] = nil
		cleaner:Destroy()
	end,
}
