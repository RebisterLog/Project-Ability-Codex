const RunService = game:GetService("RunService")
const Animate = require(script.Animate)

const SharedStand = {}

function SharedStand:HandleMovement()
	Animate(self.instance)
end

return SharedStand
