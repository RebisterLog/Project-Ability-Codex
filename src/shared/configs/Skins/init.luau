--!native

local Skins = {}

for i, specFolder in script:GetChildren() do
	if not specFolder:IsA("Folder") then continue end

	Skins[specFolder.Name] = {}

	for i, skin in specFolder:GetChildren() do
		if not skin:IsA("ModuleScript") then continue end

		Skins[specFolder.Name][skin.Name] = require(skin)
	end
end

return Skins
