const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const ForgeVFX = require(ReplicatedStorage.shared.packages.ForgeVFX)

type EmitFolderData = {
	Character: Model?,
	-- Folder of per-body-part effect copies, matched against the character's limbs.
	EffectsFolder: Folder?,
	-- Defaults to the folder name, so one folder is one stoppable slot.
	UUID: string?,
}

return {
	Characters = {},

	onStart = function(self, data: EmitFolderData)
		local character, effectsFolder, uuid = data.Character, data.EffectsFolder, data.UUID
		if not (character and effectsFolder) then return end

		if not self.Characters[character] then
			self.Characters[character] = {}

			character.Destroying:Once(function()
				self.Characters[character] = nil
			end)
		end

		const cache = self.Characters[character]
		const cleaner = cache[uuid or effectsFolder.Name] or Crane.Buttler.new()

		const toEmit = {}

		for i, bodyPartFolder in effectsFolder:GetChildren() :: { Folder } do
			const bodyPart = character:FindFirstChild(bodyPartFolder.Name)

			if bodyPart then
				const copy = bodyPartFolder:Clone()
				table.insert(toEmit, copy)
				copy.Parent = bodyPart
			end
		end

		for i, emit in toEmit do
			cleaner:Set(emit.Name, emit)

			ForgeVFX.emit(emit).Finished:andThen(function()
				cleaner:Remove(emit.Name)
			end)
		end

		self.Characters[character][uuid or effectsFolder.Name] = cleaner
	end,

	onStop = function(self, data: EmitFolderData)
		local character, folder = data.Character, data.EffectsFolder
		if not (character and folder) then return end

		const cache = self.Characters[character]
		if not cache then return end

		const cleaner = cache[data.UUID or folder.Name]
		if cleaner then cleaner:Clean() end
	end,
}
