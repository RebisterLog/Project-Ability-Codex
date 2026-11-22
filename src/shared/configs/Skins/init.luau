--!native

--- Recursively fills a skin with the missing entries of the spec's `None` skin.
--- Roblox instances, CFrames and enums are leaves: only plain tables merge.
const function mergeSkin(base: { [string]: any }, override: { [string]: any }): { [string]: any }
	const merged = table.clone(base)

	for key, value in override do
		const baseValue = merged[key]
		merged[key] = if type(baseValue) == "table" and type(value) == "table"
			then mergeSkin(baseValue, value)
			else value
	end

	return merged
end

const Skins = {}

for _, specFolder in script:GetChildren() do
	if not specFolder:IsA("Folder") then continue end

	Skins[specFolder.Name] = {}

	const defaultSkin = specFolder:FindFirstChild("None")
	const fallback = if defaultSkin and defaultSkin:IsA("ModuleScript")
		then require(defaultSkin)
		else {}

	for _, skin in specFolder:GetChildren() do
		if not skin:IsA("ModuleScript") then continue end

		Skins[specFolder.Name][skin.Name] = if skin.Name == "None"
			then require(skin)
			else mergeSkin(fallback, require(skin))
	end
end

return Skins
