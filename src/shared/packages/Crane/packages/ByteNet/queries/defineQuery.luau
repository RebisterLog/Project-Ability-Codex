--!native
--!optimize 2

local query = require(script.Parent.query)
local types = require(script.Parent.Parent.types)

return function(properties: types.queryProperties<any>)
	return function(id: number)
		return query(properties, id)
	end
end
