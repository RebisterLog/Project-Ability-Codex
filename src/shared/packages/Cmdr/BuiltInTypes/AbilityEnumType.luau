local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityNames = {}

for name, specData in require(ReplicatedStorage.shared.configs.Specs) do
	table.insert(AbilityNames, name)
end

return function (registry)
	registry:RegisterType("ability", registry.Cmdr.Util.MakeEnumType("Ability", AbilityNames))
end