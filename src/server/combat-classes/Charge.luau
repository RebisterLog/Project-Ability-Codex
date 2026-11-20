--!native
--!optimize 2

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const ChargeState = require(ReplicatedStorage.shared.combat.ChargeState)
const types = require(ServerScriptService.server.types)

type Config = { Default: ChargeState.State }

type ChargeData = {
	Id: string,
	Config: Config,
}

const Charge = {}
Charge.__index = Charge

export type Charge = ChargeData & {
	Get: (self: Charge, character: types.Character) -> number,
	Add: (self: Charge, character: types.Character, amount: number) -> number,
	Consume: (self: Charge, character: types.Character, cost: number) -> (boolean, number),
	StartFill: (self: Charge, character: types.Character) -> number,
	StopFill: (self: Charge, character: types.Character) -> number,
	schedule: (self: Charge, character: types.Character, value: ChargeState.State) -> (),
}

function Charge.new(id: string, config: Config): Charge
	return setmetatable({ Id = id, Config = config }, Charge) :: any
end

const function state(self: Charge, character: types.Character, ensure: boolean?)
	const entry = (character.Parameters :: any)[self.Id]
	const object = entry and entry.Objects[1]
	if object then return object.Value end

	if not ensure then return nil end

	const value = table.clone(self.Config.Default)
	if not character.TornDown then character:AddParameter(self.Id :: any, value :: any) end
	return value
end

const function publish(self: Charge, character: types.Character, value: ChargeState.State)
	if character.TornDown then return end

	character:SetParameterValue(self.Id :: any, value :: any)
	self:schedule(character, value)
end

function Charge:schedule(character: types.Character, value: ChargeState.State)
	if value.Filling or value.Amount <= 0 or value.DecayRate <= 0 then
		character.Cleaner:Remove(self.Id)
		return
	end

	const delay = ChargeState.ExpiryAt(value) - workspace:GetServerTimeNow()

	const function expire()
		if character.TornDown then return end

		const current = state(self, character)
		if not current or current.Filling then return end

		const now = workspace:GetServerTimeNow()
		if ChargeState.Effective(current, now) > 0 then
			self:schedule(character, current)
			return
		end

		const next = table.clone(current)
		next.Amount = 0
		next.LastGainAt = now
		character:SetParameterValue(self.Id :: any, next :: any)
	end

	character.Cleaner:Set(
		self.Id,
		if delay <= 0 then task.defer(expire) else task.delay(delay, expire)
	)
end

function Charge:Get(character: types.Character): number
	const value = state(self, character, true)
	return ChargeState.Effective(value, workspace:GetServerTimeNow())
end

function Charge:Add(character: types.Character, amount: number): number
	if amount <= 0 then return self:Get(character) end

	const now = workspace:GetServerTimeNow()
	const current = state(self, character, true)
	const next = table.clone(current)

	next.Amount = math.clamp(ChargeState.Effective(current, now) + amount, 0, next.Max)

	if next.Filling then
		next.FillStartAmount = next.Amount
		next.FillStartedAt = now
	else
		next.LastGainAt = now
	end

	publish(self, character, next)
	return next.Amount
end

function Charge:Consume(character: types.Character, cost: number): (boolean, number)
	const now = workspace:GetServerTimeNow()
	const current = state(self, character, true)
	const value = ChargeState.Effective(current, now)

	if cost <= 0 then return true, value end
	if cost > value then return false, value end

	const remaining = math.max(0, value - cost)
	const next = table.clone(current)
	next.Amount = remaining

	if next.Filling then
		next.FillStartAmount = remaining
		next.FillStartedAt = now
	elseif now > next.LastGainAt + next.HoldSeconds then
		next.LastGainAt = now - next.HoldSeconds
	end

	publish(self, character, next)
	return true, remaining
end

function Charge:StartFill(character: types.Character): number
	const now = workspace:GetServerTimeNow()
	const current = state(self, character, true)
	const value = ChargeState.Effective(current, now)
	const next = table.clone(current)

	next.Filling = true
	next.FillStartedAt = now
	next.FillStartAmount = value
	next.Amount = value
	next.LastGainAt = now

	publish(self, character, next)
	return value
end

function Charge:StopFill(character: types.Character): number
	const now = workspace:GetServerTimeNow()
	const current = state(self, character, true)
	const value = ChargeState.Effective(current, now)

	if not current.Filling then return value end

	const next = table.clone(current)

	next.Filling = false
	next.FillStartedAt = 0
	next.FillStartAmount = value
	next.Amount = value
	next.LastGainAt = now

	publish(self, character, next)
	return value
end

return Charge
