const Quests = {}

local function initQuests(container: Instance, group: { any })
	for _, module in container:GetChildren() do
		if module:IsA("ModuleScript") then group[module.Name] = require(module) end

		if module:IsA("Folder") then
			group[module.Name] = {}
			initQuests(module, group[module.Name])
		end
	end
end

initQuests(script, Quests)

return Quests
