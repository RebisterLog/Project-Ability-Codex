local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Crane = require(ReplicatedStorage.shared.packages.Crane)
local ForgeVFX = require(ReplicatedStorage.shared.packages.ForgeVFX)

return {
	Characters = {},

	onStart = function(self, character: Model, effectsFolder: Folder, uuid: string?)
		if not self.Characters[character] then
			self.Characters[character] = {}

			character.Destroying:Once(function()
				self.Characters[character] = nil
			end)
		end

		local cache = self.Characters[character]
		local cleaner =  cache[uuid or effectsFolder.Name] or Crane.Buttler.new()

		local toEmit = {}

		for i, bodyPartFolder in effectsFolder:GetChildren() :: {Folder} do
			local bodyPart = character:FindFirstChild(bodyPartFolder.Name)

			if bodyPart then
				local copy = bodyPartFolder:Clone()
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