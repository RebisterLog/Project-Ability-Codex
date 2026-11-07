const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Crane = require(ReplicatedStorage.shared.packages.Crane)
const types = require(ServerScriptService.server.types)

const VFXService = Crane:GetService("VFXService")

-- Deals damage respecting the two hold parameters:
--   DamageHold : the health bar does not move at all; the full amount is queued
--                for the replay on release and returned as `deferred`.
--   NoDeath    : damage lands as usual but never drops health below one; the
--                excess is accumulated as debt on the parameter state itself.
-- Returns (damageDealt, deferredToQueue).
const function applyDamage(character: types.Character, damage: number): (number, number)
	const humanoid = character.Humanoid
	const before = humanoid.Health

	if character:GetParameter("DamageHold") == true then
		table.insert(character.Parameters.DamageHold.Queue, {
			Kind = "Damage",
			Amount = damage,
		})
		return 0, damage
	end

	if character:GetParameter("NoDeath") == true then
		const immediate = math.min(damage, math.max(before - 1, 0))
		if immediate > 0 then humanoid:TakeDamage(immediate) end

		const excess = damage - immediate
		if excess > 0 then
			const state = character.Parameters.NoDeath
			state.Debt = (state.Debt or 0) + excess
		end

		return immediate, 0
	end

	humanoid:TakeDamage(damage)

	return math.max(before - humanoid.Health, 0), 0
end

const function deferAttack(data: types.AttackData, damage: number)
	const attack = table.clone(data)
	attack.Info = table.clone(data.Info)
	attack.Info.Damage = damage
	-- The queued attacks replay back to back, and a knockback carrying
	-- `ClearMovers` destroys the previous attack's mover mid-flight - a stack
	-- of them lands as only the last, weakest push. So the first queued attack
	-- that carries a knockback keeps it at full, ordinary strength, and every
	-- knockback accumulated after it drops the knockback entirely: the release
	-- reads as one honest shove instead of pushes cancelling each other.
	if attack.Info.Knockback then
		local knockbackTaken = false
		for _, entry in data.Victim.Parameters.DamageHold.Queue do
			if entry.Kind == "Attack" and entry.Attack.Info.Knockback then
				knockbackTaken = true
				break
			end
		end
		if knockbackTaken then attack.Info.Knockback = nil end
	end
	attack.State = table.clone(data.State)
	attack.NoDeathDeferred = true

	table.insert(data.Victim.Parameters.DamageHold.Queue, {
		Kind = "Attack",
		Attack = attack,
	})
end

const function showIndicator(Data: types.AttackData, amount: number)
	-- The health bar moves only now, so the floating number matches the payout.
	if amount > 0 then
		VFXService:StartEffect(Players:GetPlayers(), "DamageIndicator", {
			Character = Data.Victim.instance,
			Amount = amount,
		})
	end
end

return {
	Apply = applyDamage,
	Name = "Damage",
	Type = "Cast",
	Priority = 100,
	Function = function(Data: types.AttackData)
		if Data.NoDeathDeferred then
			const damage = Data.Info.Damage or 0
			if Data.State.Success and damage > 0 and Data.Victim.Humanoid.Health > 0 then
				if Data.Victim:GetParameter("DamageHold") == true then
					-- Frozen again before the queue drained: keep the attack queued
					-- for the next release instead of paying it into a frozen body.
					table.insert(Data.Victim.Parameters.DamageHold.Queue, {
						Kind = "Attack",
						Attack = Data,
					})
				elseif Data.Victim:GetParameter("GodMode") then
					-- Admin god mode takes the damage out of the payout too.
				elseif Data.Victim:GetParameter("NoDeath") == true then
					-- A cutscene hold that outlived the freeze: the payout still
					-- respects the health floor and only becomes debt.
					Data.DamageDealt = applyDamage(Data.Victim, damage)
					Data.Victim.Parameters.NoDeath.DebtFrom = Data
					Data.Victim.OnTakeDamage:Fire(Data.Attacker, Data)
				else
					Data.Victim.Humanoid:TakeDamage(damage)
					Data.Victim.OnTakeDamage:Fire(Data.Attacker, Data)
				end

				-- The queued attack kept silent during the hold; the indicator lands
				-- together with the actual payout. If the victim was frozen again
				-- before this paid out, it rides with the next replay.
				if Data.Victim:GetParameter("DamageHold") ~= true then
					showIndicator(Data, damage)
				end
			end

			Data.DamageDealt = Data.DamageDealt or 0
			return true
		end

		local deferred = 0
		if Data.State.Success and Data.Info.Damage and Data.Victim.Humanoid.Health > 0 then
			Data.Info.Damage *= Data.Attacker:GetParameter("DamageMultiplier")
			Data.Info.Damage *= Data.Victim:GetParameter("DamageReceivalMultiplier")

			-- God mode takes the damage out of the humanoid and nothing else: the
			-- multipliers, the indicator and OnTakeDamage still run, so the skills,
			-- the bots and the allies react exactly as they would to a landed hit.
			if Data.Victim:GetParameter("GodMode") then
				showIndicator(Data, Data.Info.Damage)
				Data.Victim.OnTakeDamage:Fire(Data.Attacker, Data)
				return true
			end

			const damageHold = Data.Victim:GetParameter("DamageHold") == true
			const noDeath = not damageHold and Data.Victim:GetParameter("NoDeath") == true

			if damageHold then
				-- Under DamageHold the health bar does not move at all: the whole
				-- attack - excess damage plus Knockback / Stun / Ragdoll / whatever
				-- else it carries - is queued for the replay on release and nothing
				-- rides the normal chain right now. No visual feedback either: the
				-- indicator plays only when the queued attack is actually paid out
				-- (see the `NoDeathDeferred` replay branch above), so a strike during
				-- Time Stop looks like nothing happened until time resumes.
				Data.DamageDealt = 0

				-- The victim learns who struck them immediately (bots retarget);
				-- the actual payout happens when the last DamageHold releases.
				Data.Victim.OnTakeDamage:Fire(Data.Attacker, Data)

				deferAttack(Data, Data.Info.Damage)
				return false
			end

			Data.DamageDealt, deferred = applyDamage(Data.Victim, Data.Info.Damage)

			if noDeath then
				-- The beat lands as usual - knockback, stun and ragdoll still ride
				-- the normal chain - but the health bar holds at one; the excess is
				-- tracked as debt on the parameter state (see `applyDamage`). The hit
				-- shows now; the debt is paid when the last NoDeath hold is released.
				showIndicator(Data, Data.Info.Damage)

				Data.Victim.OnTakeDamage:Fire(Data.Attacker, Data)

				if (Data.DamageDealt or 0) < Data.Info.Damage then
					Data.Victim.Parameters.NoDeath.DebtFrom = Data
				end

				return true
			end

			showIndicator(Data, Data.Info.Damage)

			Data.Victim.OnTakeDamage:Fire(Data.Attacker, Data)
		end
		return deferred <= 0
	end,
}
