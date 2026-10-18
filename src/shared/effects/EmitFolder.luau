const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const ForgeVFX = require(ReplicatedStorage.shared.packages.ForgeVFX)

return {
	Characters = {},

	onStart = function(self, character: Model, effectsFolder: Folder, uuid: string?)
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

	onStop = function(self, character: Model, uuid: string)
		if self.Characters[character] and self.Characters[character][uuid] then
			self.Characters[character][uuid]:Clean()
		end
	end,
}
