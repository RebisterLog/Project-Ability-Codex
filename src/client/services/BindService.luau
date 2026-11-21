const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)

const JoystickBinds = require(script.Parent.Parent.controls.JoystickBinds)

-- Hold-to-cast tuning. The server still revalidates every request; these only
-- keep obvious duplicate/spam requests off the wire.
const BASE_RETRY_INTERVAL = 0.12
const MAX_RETRY_INTERVAL = 0.4

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

type HeldInput = SkillRef & {
	Hold: boolean,
	AttemptAt: number,
	Interval: number,
}

-- The analyzer's Roblox definitions don't list KeyCode.Unknown, but the engine
-- does. Keep the cast in one place instead of widening every bind to `any`.
const UNKNOWN_BIND: Bind = (Enum.KeyCode :: any).Unknown

const BindService = Crane:CreateService({
	Name = "BindService",
})
BindService.Binds = {} :: { [Bind]: { Candidate } }
BindService.Held = {} :: { [string]: HeldInput }

function BindService.onStart(self: typeof(BindService))
	const LocalPlayer = Players.LocalPlayer
	self.playerProxy =
		Crane:GetService("PlayerService").Proxy :: Proxy.ProxyTab<PlayerData.PlayerData>
	self.clientSkills = Crane:GetService("ClientSkillService")
	self.Cleaner = Crane.Janitor.new()
	self.BindSignature = ""

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

	const function isHold(candidate: Candidate): boolean
		const data = skillData(candidate)
		const parameters = data and data.Parameters
		return parameters ~= nil and parameters.Hold == true
	end

	const function pick(candidates: { Candidate }): (Candidate?, boolean?)
		-- Candidates are sorted by slot then skill id. The key belongs to the
		-- first one that can actually start right now: a cooldown, a disabled
		-- skill (e.g. OnlyForStand without a stand), an absent skill or a blocked
		-- state all pass the key to the next candidate in priority order.
		for _, candidate in candidates do
			if canStart(candidate) then return candidate, isHold(candidate) end
		end

		-- Nothing is ready, but a hold-capable candidate must wait for its
		-- window while the key stays down.
		for _, candidate in candidates do
			if isHold(candidate) then return candidate, true end
		end

		return nil
	end

	const function sendStart(candidate: Candidate, hold: boolean, key: string)
		self.clientSkills:Activate(candidate.SkillId)
		Crane:GetPacket("StartSkill").send(candidate.SkillId)

		self.Held[key] = {
			Slot = candidate.Slot,
			SkillId = candidate.SkillId,
			Hold = hold,
			AttemptAt = workspace:GetServerTimeNow() + BASE_RETRY_INTERVAL,
			Interval = BASE_RETRY_INTERVAL,
		}
	end

	self.Cleaner:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		const key = inputKey(input)
		if self.Held[key] then return end -- dedupe OS / gamepad key repeat

		const remapped = JoystickBinds[input.KeyCode]
		const candidates = resolve(input, remapped)
		if not candidates then return end

		const chosen, hold = pick(candidates)
		if not chosen then return end

		sendStart(chosen, hold == true, key)
	end))

	-- Deliberately not gated by `gameProcessed`: a UI that consumes the release
	-- would otherwise leave the skill stuck in the held state.
	self.Cleaner:Add(UserInputService.InputEnded:Connect(function(input)
		const key = inputKey(input)
		const held = self.Held[key]
		if not held then return end
		self.Held[key] = nil

		self.clientSkills:Stop(held.SkillId)
		Crane:GetPacket("StopSkill").send(held.SkillId)
	end))

	self.Cleaner:Add(RunService.Heartbeat:Connect(function()
		const now = workspace:GetServerTimeNow()

		for _key, held in self.Held do
			if not held.Hold then continue end
			if now < held.AttemptAt then continue end

			held.AttemptAt = now + held.Interval

			const data = skillData(held)
			const parameters = data and data.Parameters
			if not parameters or not parameters.Enabled then continue end

			if parameters.ReleaseTime > now then
				-- Exact wake-up: no polling while the authoritative cooldown runs.
				held.AttemptAt = math.max(held.AttemptAt, parameters.ReleaseTime)
				held.Interval = BASE_RETRY_INTERVAL
				continue
			end

			if not self.clientSkills:CanStart(held.SkillId) then
				-- A stun has an exact replicated end time: wake up on it instead
				-- of polling. Other blocks (ragdoll, restraint, local prediction)
				-- fall back to a capped backoff.
				const state = self.playerProxy().CharacterState
				const stun = state and state.Parameters and state.Parameters.Stun
				if stun and stun.ExpiresAt > now then
					held.AttemptAt = math.max(held.AttemptAt, stun.ExpiresAt)
					held.Interval = BASE_RETRY_INTERVAL
				else
					held.Interval = math.min(held.Interval * 1.5, MAX_RETRY_INTERVAL)
				end
				continue
			end

			held.Interval = BASE_RETRY_INTERVAL
			self.clientSkills:Activate(held.SkillId)
			Crane:GetPacket("StartSkill").send(held.SkillId)
		end
	end))
end

return BindService
