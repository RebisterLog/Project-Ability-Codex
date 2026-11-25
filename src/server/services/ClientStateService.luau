--!native
--!optimize 2

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const types = require(game:GetService("ServerScriptService").server.types)

-- A sample older than this is useless for extrapolation and is dropped.
const MAX_SAMPLE_AGE = 0.5
-- Cap the extrapolation window even if the client reports an ancient sample.
const MAX_LATENCY = 0.3
-- Anything faster than this is treated as an invalid client report.
const MAX_SPEED = 64
-- Melee compensation stays small on purpose. Normal top speed is Run (25
-- studs/s); Dash is 100 and falling can exceed that. Extrapolating by either
-- would put a punch 10+ studs away or under the floor.
const MAX_COMPENSATION_SPEED = 25
const MAX_PREDICTION_OFFSET = 3
-- Accepting a client pose beyond this distance from the server replica is not
-- worth it: a desynced/dashing client falls back to the authoritative pose.
const MAX_ACCEPT_DISTANCE = 4
-- Slack on top of speed * latency, always clamped by MAX_ACCEPT_DISTANCE.
const BUFFER = 1.5

const ClientStateService = Crane:CreateService({
	Name = "ClientStateService",
})

-- Initialised at declaration time so Get/GetMetadata work even when Crane
-- starts services in an arbitrary onStart order.
ClientStateService.Samples = {} :: { [Player]: types.ClientStateSample }

const function finite(value: number): boolean
	-- GetServerTimeNow() is epoch-scale (~1.8e9) in this Studio build, so the
	-- bound must be generous; NaN fails the self-comparison.
	return value == value and math.abs(value) < 1e15
end

const function validVector(value: Vector3): boolean
	return finite(value.X) and finite(value.Y) and finite(value.Z)
end

function ClientStateService.onStart(self: typeof(ClientStateService))
	self.Cleaner = Crane.Janitor.new()

	self.Cleaner:Add(
		Crane:GetPacket("ClientState")
			.listen(function(data: types.ClientStateSample, player: Player)
				if not finite(data.Time) then return end

				const now = workspace:GetServerTimeNow()
				const age = now - data.Time
				-- Small negative values are clock noise; large ones are spoofing.
				if age < -0.05 or age > MAX_SAMPLE_AGE then return end
				if not validVector(data.Position) then return end

				if data.Velocity then
					if not validVector(data.Velocity) then return end
					if data.Velocity.Magnitude > MAX_SPEED then return end
				end
				if data.LookYaw and not finite(data.LookYaw) then return end

				const previous = self.Samples[player]

				self.Samples[player] = {
					Time = data.Time,
					Position = data.Position,
					Velocity = data.Velocity or (previous and previous.Velocity) or Vector3.zero,
					LookYaw = data.LookYaw or (previous and previous.LookYaw),
					IsGrounded = data.IsGrounded,
				}
			end)
	)

	self.Cleaner:Add(Players.PlayerRemoving:Connect(function(player: Player)
		self.Samples[player] = nil
	end))
end

--- Returns the newest trusted sample for a player, or nil when it is missing,
--- stale or malformed. Callers must treat nil as "use the server pose".
function ClientStateService.Get(
	self: typeof(ClientStateService),
	player: Player?
): types.ClientStateSample?
	if not player then return nil end

	const sample = self.Samples[player]
	if not sample then return nil end

	if workspace:GetServerTimeNow() - sample.Time > MAX_SAMPLE_AGE then
		self.Samples[player] = nil
		return nil
	end

	return sample
end

--- Builds the compensated pose used to move a caster's hitbox origin. Both the
--- accepted client position and the extrapolation are bounded: only horizontal
--- movement at up to Run speed is predicted, by at most 3 studs. A dashing or
--- falling client is therefore never able to drag a melee hitbox underground
--- or 10+ studs away from the character.
function ClientStateService.GetMetadata(
	self: typeof(ClientStateService),
	character: types.Character
): types.CombatMetadata?
	const rootPart = character.RootPart
	if not rootPart or not rootPart.Parent then return nil end

	const sample = self:Get(character.Player)
	if not sample then return nil end

	const latency = math.clamp(workspace:GetServerTimeNow() - sample.Time, 0, MAX_LATENCY)

	const velocity = sample.Velocity or Vector3.zero
	if velocity.Magnitude > MAX_SPEED then return nil end

	-- Vertical velocity is never predicted: a hard landing reports -80 Y and
	-- would push the origin straight through the floor. Keep the server's Y.
	const horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	const speed = math.min(horizontal.Magnitude, MAX_COMPENSATION_SPEED)
	const tolerance = math.min(speed * latency + BUFFER, MAX_ACCEPT_DISTANCE)
	const position = Vector3.new(sample.Position.X, rootPart.Position.Y, sample.Position.Z)
	if (position - rootPart.Position).Magnitude > tolerance then return nil end

	const lookVector = if sample.LookYaw
		then CFrame.Angles(0, sample.LookYaw :: number, 0).LookVector
		else rootPart.CFrame.LookVector
	const cframe = CFrame.new(position, position + lookVector)

	const travel = math.min(speed * latency, MAX_PREDICTION_OFFSET)
	const predictedVelocity = if horizontal.Magnitude > 0.001
		then horizontal.Unit * speed
		else Vector3.zero
	const predicted = cframe + (if speed > 0 then horizontal.Unit * travel else Vector3.zero)


	return {
		Position = position,
		LookVector = lookVector,
		Velocity = predictedVelocity,
		Latency = latency,
		Predicted = predicted,
		IsGrounded = sample.IsGrounded,
		Compensated = true,
	}
end

function ClientStateService.Destroy(self: typeof(ClientStateService))
	self.Cleaner:Destroy()
	table.clear(self.Samples)
end

return ClientStateService
