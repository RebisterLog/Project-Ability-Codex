const BotSpawners = {}

for _, module in script:GetChildren() do
	if module:IsA("ModuleScript") then BotSpawners[module.Name] = require(module) end
end

return BotSpawners
