const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const ServerScriptService = game:GetService("ServerScriptService")

const Bridge = require(ReplicatedStorage.shared.packages.Bridge)
const Crane = require(ReplicatedStorage.shared.packages.Crane)

--[[
	Server half of the Crane Bridge.

	Publishes ServerScriptService.Bridge, a Request/Response BindableEvent pair an
	agent can address directly from the server DataModel.

	ServerScriptService never replicates, so on a published game this container is
	not merely inert, it is absent: there is no address for a remote client to
	find and nothing to subscribe to.

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
	self.Container = Bridge.CreateContainer(ServerScriptService, "Bridge")

	self.Cleaner:Add(self.Container.Folder)
	self.Cleaner:Connect(self.Container.Request.Event, function(payload)
		Bridge.Dispatch(payload, self.Container.Response)
	end)
end

return BridgeService
