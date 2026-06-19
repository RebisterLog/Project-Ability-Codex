local function freezeDeep(value: {any})
	if typeof(value) ~= "table" then
		return
	end

	if not table.isfrozen(value) then
		table.freeze(value)
	end

	for _, innerValue in value do
		freezeDeep(innerValue)
	end
end

return freezeDeep
