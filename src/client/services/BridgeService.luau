const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

const Bridge = require(ReplicatedStorage.shared.packages.Bridge)
const Crane = require(ReplicatedStorage.shared.packages.Crane)

--[[
	Client half of the Crane Bridge.

	Publishes ReplicatedStorage.Bridge, a Request/Response BindableEvent pair an
	agent can address directly from the client DataModel.

	The server never connects to this pair. The container replicates upward, but a
	BindableEvent signal only ever fires on the side that owns the connection, so
	nothing here is reachable from the other side of the boundary.

	Inert outside a Studio playtest. Nothing is created and nothing is stored on
	the service, so there is no callable surface to reach for either.
]]

const BridgeService = Crane:CreateService({
	Name = "BridgeService",
	LoadOrder = 1000,
})

function BridgeService:onInit()
	if not RunService:IsStudio() then return end

	self.Cleaner = Crane.Buttler.new()
	self.Container = Bridge.CreateContainer(ReplicatedStorage, "Bridge")

	self.Cleaner:Add(self.Container.Folder)
	self.Cleaner:Connect(self.Container.Request.Event, function(payload)
		Bridge.Dispatch(payload, self.Container.Response)
	end)
end

return BridgeService
