const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")
const LocalPlayer = Players.LocalPlayer
const Mouse = LocalPlayer:GetMouse()

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)

const JoystickBinds = require(script.Parent.Parent.controls.JoystickBinds)

const HOLD_SEND_INTERVAL = 0.08
const STOP_REPEATS = 4
const STOP_REPEAT_INTERVAL = 0.05
const MAX_AIM_DISTANCE = 120

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

-- The engine has KeyCode.Unknown; the analyzer does not.
const UNKNOWN_BIND: Bind = (Enum.KeyCode :: any).Unknown

const BindService = Crane:CreateService({
	Name = "BindService",
})
BindService.Binds = {} :: { [Bind]: { Candidate } }
BindService.Held = {} :: { [string]: SkillRef }
BindService.StopQueue = {} :: { [string]: PendingStop }

function BindService.GetSkillData(self: typeof(BindService), ref: SkillRef)
	const skills = self.playerProxy().Skills
	const slotSkills = skills and skills[ref.Slot]
	return slotSkills and slotSkills[ref.SkillId]
end

function BindService.RebuildBinds(self: typeof(BindService))
	const all: { Candidate } = {}
	const parts: { string } = {}

	for slot, _rank in SLOT_RANK do
		const slotName = slot :: Slot
		const skills = self.playerProxy().Skills
		const slotSkills = skills and skills[slotName]
		if not slotSkills then continue end

		for skillId, data in slotSkills do
			const bind = data and data.Parameters and data.Parameters.Bind
			-- Unknown is also what a mouse click reports; never bind it.
			if bind == nil or bind == UNKNOWN_BIND then continue end

			table.insert(all, { Bind = bind :: Bind, Slot = slotName, SkillId = skillId })
			table.insert(parts, `{slotName}:{skillId}:{tostring(bind)}`)
		end
	end

	table.sort(all, function(a, b)
		if SLOT_RANK[a.Slot] ~= SLOT_RANK[b.Slot] then
			return SLOT_RANK[a.Slot] < SLOT_RANK[b.Slot]
		end
		return a.SkillId < b.SkillId
	end)
	table.sort(parts)

	const signature = table.concat(parts, "|")
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

function BindService.InputKey(_self: typeof(BindService), input: InputObject): string
	-- Keep the InputObject: a remapped EnumItem has no KeyCode.
	const remapped = JoystickBinds[input.KeyCode]
	return tostring(input.KeyCode)
		.. "|"
		.. tostring(input.UserInputType)
		.. "|"
		.. tostring(remapped)
end

function BindService.Resolve(
	self: typeof(BindService),
	input: InputObject,
	remapped: Bind?
): { Candidate }?
	if remapped then
		const found = self.Binds[remapped]
		if found then return found end
	end

	return self.Binds[input.KeyCode] or self.Binds[input.UserInputType]
end

function BindService.CanStart(self: typeof(BindService), candidate: Candidate): boolean
	const data = self:GetSkillData(candidate)
	const parameters = data and data.Parameters
	if not parameters or not parameters.Enabled then return false end
	if parameters.ReleaseTime > workspace:GetServerTimeNow() then return false end

	return self.clientSkills:CanStart(candidate.SkillId)
end

function BindService.Pick(self: typeof(BindService), candidates: { Candidate }): Candidate?
	for _, candidate in candidates do
		if self:CanStart(candidate) then return candidate end
	end

	return candidates[1]
end

function BindService.IsRepeatable(self: typeof(BindService), ref: SkillRef): boolean
	const data = self:GetSkillData(ref)
	const parameters = data and data.Parameters
	return parameters ~= nil and parameters.Toggle ~= true
end

function BindService.AimPointFor(self: typeof(BindService), ref: SkillRef): Vector3?
	const data = self:GetSkillData(ref)
	const parameters = data and data.Parameters
	if not parameters or not parameters.AimRequired then return nil end

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

function BindService.SendStart(self: typeof(BindService), candidate: Candidate, key: string)
	self.clientSkills:Activate(candidate.SkillId)
	Crane:GetPacket("StartSkill").send({
		Id = candidate.SkillId,
		AimPoint = self:AimPointFor(candidate),
	})

	self.StopQueue[candidate.SkillId] = nil
	self.Held[key] = { Slot = candidate.Slot, SkillId = candidate.SkillId }
end

function BindService.onStart(self: typeof(BindService))
	self.playerProxy =
		Crane:GetService("PlayerService").Proxy :: Proxy.ProxyTab<PlayerData.PlayerData>
	self.clientSkills = Crane:GetService("ClientSkillService")
	self.Cleaner = Crane.Janitor.new()
	self.BindSignature = ""
	self.NextHoldSendAt = 0
	self.RoundRobin = 0

	self.Cleaner:Add(self.playerProxy:Subscribe("AnyChange", { "Skills" }, function()
		self:RebuildBinds()
	end))
	self:RebuildBinds()

	self.Cleaner:Add(LocalPlayer.CharacterAdded:Connect(function()
		table.clear(self.Held)
		table.clear(self.StopQueue)
	end))

	self.Cleaner:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		const key = self:InputKey(input)
		if self.Held[key] then return end

		const remapped = JoystickBinds[input.KeyCode]
		const candidates = self:Resolve(input, remapped)
		if not candidates then return end

		const chosen = self:Pick(candidates)
		if not chosen then return end

		self:SendStart(chosen, key)
	end))

	self.Cleaner:Add(UserInputService.InputEnded:Connect(function(input)
		const key = self:InputKey(input)
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

		if now >= self.NextHoldSendAt then
			self.NextHoldSendAt = now + HOLD_SEND_INTERVAL

			const keys: { string } = {}
			for key, held in self.Held do
				if not self:IsRepeatable(held) then continue end
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
					AimPoint = self:AimPointFor(held),
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
