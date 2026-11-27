const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const UserInputService = game:GetService("UserInputService")

const Fusion = require(ReplicatedStorage.shared.packages.Fusion)
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Proxy = require(ReplicatedStorage.shared.packages.Proxy)
const PlayerData = require(ReplicatedStorage.shared.schemas.PlayerData)
const AllowedBinds = require(ReplicatedStorage.shared.configs.Binds)
const Specs = require(ReplicatedStorage.shared.configs.Specs)

const peek = Fusion.peek

const SkillBarView = require(script.Parent.Parent.views.SkillBarView)

const REBIND_HOLD = 1
const SLOT_ORDER = { "Spec", "SubSpec" }
const UNKNOWN_BIND = (Enum.KeyCode :: any).Unknown

type Slot = "Spec" | "SubSpec"

type CellState = {
	DisplayName: Fusion.Value<string>,
	BindLabel: Fusion.Value<string>,
	Remaining: Fusion.Value<number>,
	Ratio: Fusion.Value<number>,
	Pop: Fusion.Value<number>,
	Rebinding: Fusion.Value<boolean>,
}

const function bindLabel(bind: any): string
	if not bind or bind == UNKNOWN_BIND then return "" end
	for _, option in AllowedBinds.Allowed do
		if option.Bind == bind then return option.Label end
	end

	return tostring(bind)
end

const function inputBind(input: InputObject): any
	for _, option in AllowedBinds.Allowed do
		if option.Bind == input.KeyCode or option.Bind == input.UserInputType then
			return option.Bind
		end
	end

	return nil
end

return function(
	scope: Fusion.Scope,
	playerProxy: Proxy.ProxyTab<PlayerData.PlayerData>,
	_gameProxy: any
)
	const barScope = scope:innerScope()
	const bindService = Crane:GetService("BindService")

	const cells = barScope:Value({} :: { [string]: SkillBarView.SkillCell })
	const states: { [string]: CellState } = {}
	const releaseTimes: { [string]: number } = {}
	const startRemaining: { [string]: number } = {}
	const popThreads: { any } = {}

	local cellSignature = ""
	local rebindingKey: string? = nil
	local holdThread: any = nil

	const function specNameFor(slot: Slot): string?
		const source = playerProxy()
		const specId = if slot == "Spec" then source.Spec else source.SubSpec
		if not specId or specId == "None" then return nil end
		const owned = source.Specs and source.Specs[specId]
		return owned and owned.Name or nil
	end

	const function stateFor(key: string): CellState
		const existing = states[key]
		if existing then return existing end

		const created: CellState = {
			DisplayName = barScope:Value(""),
			BindLabel = barScope:Value(""),
			Remaining = barScope:Value(0),
			Ratio = barScope:Value(0),
			Pop = barScope:Value(0),
			Rebinding = barScope:Value(false),
		}
		states[key] = created
		return created
	end

	const refresh = function()
		const source = playerProxy()
		const found: { [string]: { slot: Slot, id: string, name: string, bind: any } } = {}
		const ordered: { string } = {}

		for _, slot in SLOT_ORDER do
			const slotName = slot :: Slot
			const slotSkills = source.Skills and source.Skills[slotName]
			if not slotSkills then continue end

			const specName = specNameFor(slotName)
			if not specName then continue end

			const ids: { string } = {}
			for skillId in slotSkills do
				table.insert(ids, skillId)
			end
			table.sort(ids)

			for _, skillId in ids do
				if AllowedBinds.HiddenSkills[skillId] then continue end

				const parameters = slotSkills[skillId] and slotSkills[skillId].Parameters
				if not parameters then continue end
				if parameters.Enabled ~= true then continue end
				if parameters.Bind == nil or parameters.Bind == UNKNOWN_BIND then continue end

				const key = `{slotName}:{skillId}`
				found[key] = {
					slot = slotName,
					id = skillId,
					name = parameters.DisplayName or skillId,
					bind = parameters.Bind,
				}
				table.insert(ordered, key)
			end
		end

		for key, entry in found do
			const state = stateFor(key)
			state.DisplayName:set(entry.name)
			state.BindLabel:set(bindLabel(entry.bind))
		end

		const signature = table.concat(ordered, "|")
		if signature == cellSignature then return end
		cellSignature = signature

		const next: { [string]: SkillBarView.SkillCell } = {}
		for index, key in ordered do
			const entry = found[key]
			const state = stateFor(key)
			const name = specNameFor(entry.slot) or ""
			const specInfo = Specs[name]
			next[key] = {
				Id = entry.id,
				Slot = entry.slot,
				SpecName = name,
				Order = index,
				Palette = specInfo and specInfo.Palette or nil,
				DisplayName = state.DisplayName,
				BindLabel = state.BindLabel,
				Remaining = state.Remaining,
				Ratio = state.Ratio,
				Pop = state.Pop,
				Rebinding = state.Rebinding,
			}
		end

		cells:set(next)
	end

	refresh()

	table.insert(barScope, playerProxy:Subscribe("AnyChange", { "Skills" }, refresh))
	table.insert(barScope, playerProxy:Subscribe("AnyChange", { "Specs" }, refresh))
	table.insert(barScope, playerProxy:Subscribe("ChangeValue", { "Spec" }, refresh))
	table.insert(barScope, playerProxy:Subscribe("ChangeValue", { "SubSpec" }, refresh))

	table.insert(
		barScope,
		RunService.Heartbeat:Connect(function()
			const now = workspace:GetServerTimeNow()
			const source = playerProxy()

			for key, state in states do
				const separator = string.find(key, ":", 1, true)
				const slot = key:sub(1, separator - 1) :: Slot
				const skillId = key:sub(separator + 1)
				const slotSkills = source.Skills and source.Skills[slot]
				const data = slotSkills and slotSkills[skillId]
				const release = if data and data.Parameters
					then data.Parameters.ReleaseTime or 0
					else 0

				if release > (releaseTimes[key] or 0) then
					startRemaining[key] = math.max(release - now, 0)
				end
				releaseTimes[key] = release

				const remaining = math.max(release - now, 0)
				state.Remaining:set(remaining)

				const start = startRemaining[key] or 0
				state.Ratio:set(if start > 0 then math.clamp(remaining / start, 0, 1) else 0)
			end
		end)
	)

	const cancelRebind = function()
		if holdThread then
			task.cancel(holdThread)
			holdThread = nil
		end

		if rebindingKey then
			const state = states[rebindingKey]
			if state then state.Rebinding:set(false) end
			rebindingKey = nil
			bindService.Rebinding = false
		end
	end

	const onHoldStart = function(key: string)
		if rebindingKey then return end
		cancelRebind()

		holdThread = task.delay(REBIND_HOLD, function()
			holdThread = nil
			if not peek(cells)[key] then return end

			rebindingKey = key
			const state = states[key]
			if state then state.Rebinding:set(true) end
			bindService.Rebinding = true
		end)
	end

	const onHoldEnd = function(_key: string)
		if holdThread then
			task.cancel(holdThread)
			holdThread = nil
		end
	end

	table.insert(
		barScope,
		UserInputService.InputBegan:Connect(function(input)
			if not rebindingKey then return end

			const bind = inputBind(input)
			if not bind then return end

			const descriptor = peek(cells)[rebindingKey]
			cancelRebind()
			if not descriptor then return end

			Crane:GetPacket("RebindSkill").send({
				SpecName = descriptor.SpecName,
				SkillId = descriptor.Id,
				Bind = tostring(bind),
			})
		end)
	)

	table.insert(
		barScope,
		bindService.SkillActivated:Connect(function(slot: string, skillId: string)
			const key = `{slot}:{skillId}`
			const state = states[key]
			if not state then return end

			state.Pop:set(1)
			table.insert(
				popThreads,
				task.delay(0.12, function()
					state.Pop:set(0)
				end)
			)
		end)
	)

	table.insert(barScope, function()
		for _, thread in popThreads do
			task.cancel(thread)
		end
		cancelRebind()
	end)

	return SkillBarView(barScope, {
		Skills = cells,
		OnHoldStart = onHoldStart,
		OnHoldEnd = onHoldEnd,
	})
end
