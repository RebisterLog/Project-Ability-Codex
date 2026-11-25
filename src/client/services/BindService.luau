const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")
const Mouse = Players.LocalPlayer:GetMouse()

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)

const JoystickBinds = require(script.Parent.Parent.controls.JoystickBinds)

-- ByteNet allows only 512 bytes/sec per player for ALL client packets. This is
-- a shared budget across every held key, not a per-key interval: ~12 packets/s
-- total leaves room for StopSkill and proxy patches.
const HOLD_SEND_INTERVAL = 0.08
-- StopSkill is idempotent on the server. Repeating it briefly after a release
-- guarantees at least one copy survives a dropped packet.
const STOP_REPEATS = 4
const STOP_REPEAT_INTERVAL = 0.05
-- Server toggles that have no client module with a `Toggle` flag. A repeated
-- StartSkill would flip them back and forth while the key is held.
const NON_REPEATABLE = { Summon = true }

-- Skills that consume a world-space cursor point. Sending it for every bind
-- would waste ByteNet's shared 512 B/s budget, so only these ids opt in.
const AIMED_SKILLS = { MarkedKnives = true }
const MAX_AIM_DISTANCE = 120

-- First priority level. Candidates inside one slot are sorted by skill id.
const SLOT_RANK = { Spec = 1, SubSpec = 2 }

type Slot = "Spec" | "SubSpec"
type Bind = Enum.KeyCode | Enum.UserInputType

type SkillRef = {
	Slot: Slot,
	SkillId: string,
}

type Candidate = SkillRef & {
	Bind: Bind,
}

type PendingStop = {
	Left: number,
	NextAt: number,
}

-- The analyzer's Roblox definitions don't list KeyCode.Unknown, but the engine
-- does. Keep the cast in one place instead of widening every bind to `any`.
const UNKNOWN_BIND: Bind = (Enum.KeyCode :: any).Unknown

const BindService = Crane:CreateService({
	Name = "BindService",
})
BindService.Binds = {} :: { [Bind]: { Candidate } }
BindService.Held = {} :: { [string]: SkillRef }
BindService.StopQueue = {} :: { [string]: PendingStop }

function BindService.onStart(self: typeof(BindService))
	const LocalPlayer = Players.LocalPlayer
	self.playerProxy =
		Crane:GetService("PlayerService").Proxy :: Proxy.ProxyTab<PlayerData.PlayerData>
	self.clientSkills = Crane:GetService("ClientSkillService")
	self.Cleaner = Crane.Janitor.new()
	self.BindSignature = ""
	self.NextHoldSendAt = 0
	self.RoundRobin = 0

	const function skillData(ref: SkillRef)
		const skills = self.playerProxy().Skills
		const slotSkills = skills and skills[ref.Slot]
		return slotSkills and slotSkills[ref.SkillId]
	end

	const function rebuildBinds()
		const all: { Candidate } = {}
		const parts: { string } = {}

		for slot, _rank in SLOT_RANK do
			const slotName = slot :: Slot
			const skills = self.playerProxy().Skills
			const slotSkills = skills and skills[slotName]
			if not slotSkills then continue end

			for skillId, data in slotSkills do
				const bind = data and data.Parameters and data.Parameters.Bind

				-- `Enum.KeyCode.Unknown` is also what a mouse click reports as
				-- its KeyCode. A skill left on the default bind would therefore
				-- fire on every click, so it must never enter the table.
				if bind == nil or bind == UNKNOWN_BIND then continue end

				table.insert(all, { Bind = bind :: Bind, Slot = slotName, SkillId = skillId })
				table.insert(parts, `{slotName}:{skillId}:{tostring(bind)}`)
			end
		end

		-- Deterministic priority: Spec before SubSpec, then alphabetically.
		table.sort(all, function(a, b)
			if SLOT_RANK[a.Slot] ~= SLOT_RANK[b.Slot] then
				return SLOT_RANK[a.Slot] < SLOT_RANK[b.Slot]
			end
			return a.SkillId < b.SkillId
		end)
		table.sort(parts)

		const signature = table.concat(parts, "|")
		-- Nested patches (ReleaseTime, Enabled, ...) also trigger this subtree
		-- subscription. Only a real rebind may invalidate held inputs.
		if signature ~= self.BindSignature then
			table.clear(self.Held)
			table.clear(self.StopQueue)
			self.BindSignature = signature
		end

		table.clear(self.Binds)
		for _, candidate in all do
			const list = self.Binds[candidate.Bind]
			if list then
				table.insert(list, candidate)
			else
				self.Binds[candidate.Bind] = { candidate }
			end
		end
	end

	self.Cleaner:Add(self.playerProxy:Subscribe("AnyChange", { "Skills" }, rebuildBinds))
	rebuildBinds()

	self.Cleaner:Add(LocalPlayer.CharacterAdded:Connect(function()
		table.clear(self.Held)
		table.clear(self.StopQueue)
	end))

	-- Keep the original InputObject intact: after a gamepad remap the old code
	-- replaced it with an EnumItem and then indexed `.KeyCode` on it.
	const function inputKey(input: InputObject): string
		const remapped = JoystickBinds[input.KeyCode]
		return tostring(input.KeyCode)
			.. "|"
			.. tostring(input.UserInputType)
			.. "|"
			.. tostring(remapped)
	end

	const function resolve(input: InputObject, remapped: Bind?): { Candidate }?
		if remapped then
			const found = self.Binds[remapped]
			if found then return found end
		end

		return self.Binds[input.KeyCode] or self.Binds[input.UserInputType]
	end

	const function canStart(candidate: Candidate): boolean
		const data = skillData(candidate)
		const parameters = data and data.Parameters
		if not parameters or not parameters.Enabled then return false end

		const now = workspace:GetServerTimeNow()
		if parameters.ReleaseTime > now then return false end

		return self.clientSkills:CanStart(candidate.SkillId)
	end

	const function pick(candidates: { Candidate }): Candidate?
		-- Candidates are sorted by slot then skill id. The key belongs to the
		-- first one that can actually start right now: a cooldown, a disabled
		-- skill (e.g. OnlyForStand without a stand), an absent skill or a blocked
		-- state all pass the key to the next candidate in priority order.
		for _, candidate in candidates do
			if canStart(candidate) then return candidate end
		end

		-- Nothing is ready: every skill is hold-capable by default, so the
		-- highest-priority candidate keeps the key and waits for its window.
		return candidates[1]
	end

	const function isRepeatable(skillId: string): boolean
		if NON_REPEATABLE[skillId] then return false end
		return not self.clientSkills:IsToggle(skillId)
	end

	-- ShiftLock pins the cursor in the centre, so Mouse.Hit is meaningless:
	-- aim at the maximum range along the character's own look vector instead.
	const function aimPointFor(skillId: string): Vector3?
		if not AIMED_SKILLS[skillId] then return nil end

		const character = LocalPlayer.Character
		const root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then return nil end

		const farPoint = root.Position + root.CFrame.LookVector * MAX_AIM_DISTANCE
		const lockService = Crane:GetService("TargetLockService") :: any
		const shiftLocked = (lockService and lockService.Locked == true)
			or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		if shiftLocked then return farPoint end

		const hit = Mouse.Hit
		if not hit then return farPoint end

		const delta = hit.Position - root.Position
		if delta.Magnitude > MAX_AIM_DISTANCE then
			return root.Position + delta.Unit * MAX_AIM_DISTANCE
		end
		return hit.Position
	end

	const function sendStart(candidate: Candidate, key: string)
		self.clientSkills:Activate(candidate.SkillId)
		Crane:GetPacket("StartSkill").send({
			Id = candidate.SkillId,
			AimPoint = aimPointFor(candidate.SkillId),
		})

		-- A fresh press cancels any pending release packets for this skill, so
		-- a quick re-tap cannot be stopped by a stale copy from the last hold.
		self.StopQueue[candidate.SkillId] = nil
		self.Held[key] = { Slot = candidate.Slot, SkillId = candidate.SkillId }
	end

	self.Cleaner:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		const key = inputKey(input)
		if self.Held[key] then return end -- dedupe OS / gamepad key repeat

		const remapped = JoystickBinds[input.KeyCode]
		const candidates = resolve(input, remapped)
		if not candidates then return end

		const chosen = pick(candidates)
		if not chosen then return end

		sendStart(chosen, key)
	end))

	-- Deliberately not gated by `gameProcessed`: a UI that consumes the release
	-- would otherwise leave the skill stuck in the held state.
	self.Cleaner:Add(UserInputService.InputEnded:Connect(function(input)
		const key = inputKey(input)
		const held = self.Held[key]
		if not held then return end
		self.Held[key] = nil

		self.clientSkills:Stop(held.SkillId)
		self.StopQueue[held.SkillId] = {
			Left = STOP_REPEATS,
			NextAt = workspace:GetServerTimeNow(),
		}
	end))

	self.Cleaner:Add(RunService.Heartbeat:Connect(function()
		const now = workspace:GetServerTimeNow()

		-- Every held bind keeps requesting its skill; the server validates.
		-- One shared slot per tick keeps the client inside ByteNet's 512 B/s
		-- budget even when several keys are held at once.
		if now >= self.NextHoldSendAt then
			self.NextHoldSendAt = now + HOLD_SEND_INTERVAL

			const keys: { string } = {}
			for key, held in self.Held do
				if not isRepeatable(held.SkillId) then continue end
				-- While a different skill owns the server's cast lock every
				-- request would be rejected. Drop it from the rotation and
				-- keep the hold armed, so casting does not queue up behind the
				-- current one. The key reappears as soon as the lock clears.
				if self.clientSkills:IsBusy(held.SkillId) then continue end
				table.insert(keys, key)
			end

			if #keys > 0 then
				self.RoundRobin = self.RoundRobin % #keys
				const key = keys[self.RoundRobin + 1]
				self.RoundRobin += 1

				const held = self.Held[key]
				if not self.clientSkills:IsActive(held.SkillId) then
					self.clientSkills:Activate(held.SkillId)
				end

				Crane:GetPacket("StartSkill").send({
					Id = held.SkillId,
					AimPoint = aimPointFor(held.SkillId),
				})
			end
		end

		for skillId, pending in self.StopQueue do
			if now < pending.NextAt then continue end

			pending.NextAt = now + STOP_REPEAT_INTERVAL
			pending.Left -= 1
			if pending.Left <= 0 then self.StopQueue[skillId] = nil end

			Crane:GetPacket("StopSkill").send(skillId)
		end
	end))
end

return BindService
