const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

const Crane = require(ReplicatedStorage.shared.packages.Crane)

const LocalPlayer = Players.LocalPlayer

-- ByteNet shares a 512 B/s client -> server budget between ALL packets, so the
-- reference's 75 Hz full-pose stream cannot be used here. 8 Hz plus diffing the
-- rarely changing fields keeps this stream at ~21-37 B per sample.
const SEND_INTERVAL = 0.125
const VELOCITY_EPSILON = 1
const YAW_EPSILON = 0.02

const ClientStateService = Crane:CreateService({
	Name = "ClientStateService",
})

const function angleDelta(a: number, b: number): number
	const delta = (a - b) % (math.pi * 2)
	return if delta > math.pi then delta - math.pi * 2 else delta
end

function ClientStateService.onStart(self: typeof(ClientStateService))
	self.Packet = Crane:GetPacket("ClientState")
	self.Cleaner = Crane.Janitor.new()
	self.NextSendAt = 0
	self.LastVelocity = nil :: Vector3?
	self.LastLookYaw = nil :: number?

	-- Client services run inside the Main Actor, where RenderStepped is not
	-- dispatched. Heartbeat is the parallel-safe frame signal here.
	self.Cleaner:Add(RunService.Heartbeat:Connect(function()
		const now = os.clock()
		if now < self.NextSendAt then return end
		self.NextSendAt = now + SEND_INTERVAL

		const character = LocalPlayer.Character
		const rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not rootPart or not rootPart:IsA("BasePart") then return end

		const velocity = rootPart.AssemblyLinearVelocity
		const look = rootPart.CFrame.LookVector
		-- Root rotation is yaw-dominant: CFrame.Angles(0, yaw, 0).LookVector is
		-- (-sin(yaw), 0, -cos(yaw)), so this round-trips exactly on the server.
		const lookYaw = math.atan2(-look.X, -look.Z)

		const sendVelocity = self.LastVelocity == nil
			or (velocity - (self.LastVelocity :: Vector3)).Magnitude > VELOCITY_EPSILON
		const sendLookYaw = self.LastLookYaw == nil
			or math.abs(angleDelta(lookYaw, self.LastLookYaw :: number)) > YAW_EPSILON

		self.Packet.send({
			Time = workspace:GetServerTimeNow(),
			Position = rootPart.Position,
			Velocity = if sendVelocity then velocity else nil,
			LookYaw = if sendLookYaw then lookYaw else nil,
		})

		if sendVelocity then self.LastVelocity = velocity end
		if sendLookYaw then self.LastLookYaw = lookYaw end
	end))
end

function ClientStateService.Destroy(self: typeof(ClientStateService))
	self.Cleaner:Destroy()
end

return ClientStateService
