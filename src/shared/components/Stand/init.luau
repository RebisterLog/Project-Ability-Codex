local RunService = game:GetService("RunService")
local Animate = require(script.Animate)

local SharedStand = {}

function SharedStand:HandleMovement()
	Animate(self.instance)
end

return SharedStand
