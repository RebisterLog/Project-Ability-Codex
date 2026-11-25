--!native
--!optimize 2

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Configs = require(ReplicatedStorage.shared.configs.Ammo)
const types = require(ServerScriptService.server.types)

const Ammo = {}

const function configOf(id: string)
	const config = (Configs :: any)[id]
	if not config then error(`[Ammo] Unknown ammo id "{id}"`, 3) end
	return config
end

const function read(character: types.Character, id: string): any?
	const all = (character:GetParameter("Ammo") :: any) or {}
	return all[id]
end

const function write(character: types.Character, id: string, entry: any)
	const all = table.clone((character:GetParameter("Ammo") :: any) or {})
	all[id] = entry
	character:SetParameterValue("Ammo" :: any, all :: any)
end

const function schedule(character: types.Character, id: string, delay: number)
	const key = "Ammo/" .. id
	const previous = character.Cleaner:Get(key) :: thread?
	if previous then task.cancel(previous) end

	character.Cleaner:Set(
		key,
		task.delay(delay, function()
			if character.TornDown or character.Humanoid.Health <= 0 then return end
			if Ammo.Get(character, id) < (configOf(id).Max :: number) then
				schedule(character, id, configOf(id).RegenInterval :: number)
			end
		end)
	)
end

function Ammo.Get(character: types.Character, id: string): number
	const config = configOf(id)
	const entry = read(character, id)
	if not entry then return config.Max :: number end

	const now = workspace:GetServerTimeNow()
	if
		(entry.Amount :: number) < (config.Max :: number)
		and (entry.NextRegenAt :: number) > 0
		and now >= (entry.NextRegenAt :: number)
	then
		const next = table.clone(entry)
		next.Amount = math.min(config.Max, entry.Amount + 1)
		next.NextRegenAt = if next.Amount < config.Max then now + config.RegenInterval else 0
		write(character, id, next)
		return next.Amount
	end

	return entry.Amount
end

function Ammo.Consume(character: types.Character, id: string): boolean
	if Ammo.Get(character, id) <= 0 then return false end

	const config = configOf(id)
	const next = table.clone(read(character, id))
	next.Amount -= 1
	if next.NextRegenAt <= 0 then
		next.NextRegenAt = workspace:GetServerTimeNow() + config.RegenInterval
	end
	write(character, id, next)
	schedule(character, id, config.RegenInterval)
	return true
end

return Ammo
