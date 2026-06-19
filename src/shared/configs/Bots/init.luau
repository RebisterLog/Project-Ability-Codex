local Bots = {}

for _, module in script:GetChildren() do
	if module:IsA("ModuleScript") then
		Bots[module.Name] = require(module)
	end
end

return Bots