--!native

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Players = game:GetService("Players")
const StarterPlayer = game:GetService("StarterPlayer")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const Enums = require(ServerScriptService.server.Enums)
const MovementRules = require(ReplicatedStorage.shared.MovementRules)
const types = require(ServerScriptService.server.types)

-- Resolved lazily: the burning rig is an optional asset, and a missing one must
-- not break the character bootstrap (the effect no-ops without a rig).
const function burningRig(): Folder?
	const default = ReplicatedStorage.assets:FindFirstChild("Default")
	const combat = default and default:FindFirstChild("Combat")
	return combat and combat:FindFirstChild("Burning") :: Folder?
end

const WalkSpeedWatcher = function(self: types.Character)
	const maxWalkSpeed = self:GetParameter("MaxWalkSpeed")
	const minWalkSpeed = self:GetParameter("MinWalkSpeed")

	self.Humanoid.WalkSpeed = MovementRules.GetWalkSpeed(minWalkSpeed, maxWalkSpeed)
end

-- NoDeath pays its accumulated debt on release. The beat itself already landed
-- normally while the hold was active (knockback, ragdoll, stun); the health bar
-- simply never dropped below one and the excess was parked in `state.Debt`.
-- The payout bypasses the combat hooks by design: it is a bookkeeping death, not
-- a new attack. The victim still learns who hit them through `OnTakeDamage`.
const function NoDeathWatcher(self: types.Character, value: boolean?)
	const state = self.Parameters.NoDeath
	if value == true then
		state.Generation += 1
		state.Draining = false
		return
	end
	if state.Draining then return end

	state.Generation += 1
	state.Draining = true
	const generation = state.Generation

	task.spawn(function()
		-- A hold that reappeared before this ran cancels the payout; the debt
		-- stays on the state for the next release.
		if state.Generation ~= generation then return end

		const debt = state.Debt or 0
		const source = state.DebtFrom
		state.Debt = 0
		state.DebtFrom = nil

		if debt > 0 and self.Humanoid.Health > 0 then
			-- Raw payout: the humanoid's own Died / HealthChanged flow fires, the
			-- combat chain (Block, IFrames, Armor, Damage) is skipped on purpose.
			self.Humanoid:TakeDamage(debt)
		end

		if source then self.OnTakeDamage:Fire(source.Attacker, source) end

		if state.Generation == generation then state.Draining = false end
	end)
end

-- DamageHold queues the whole attack while it is active: the health bar does not
-- move at all, and on release every queued entry is replayed in order (attack
-- effects included). Healing keeps its order in the same queue.
const function DamageHoldWatcher(self: types.Character, value: boolean?)
	const state = self.Parameters.DamageHold
	if value == true then
		state.Generation += 1
		state.Draining = false
		return
	end
	if state.Draining then return end

	state.Generation += 1
	state.Draining = true
	const generation = state.Generation

	task.spawn(function()
		while state.Generation == generation do
			if self.Humanoid.Health <= 0 then
				table.clear(state.Queue)
				break
			end

			const entry = table.remove(state.Queue, 1)
			if not entry then break end

			if entry.Kind == "Attack" then
				Crane:GetService("CombatService"):Attack(entry.Attack)
			elseif entry.Kind == "Damage" then
				self.Humanoid:TakeDamage(entry.Amount)

				-- The tick stayed silent during the hold; its floating number
				-- shows together with the actual payout, like deferred attacks.
				if entry.Amount > 0 then
					Crane:GetService("VFXService")
						:StartEffect(Players:GetPlayers(), "DamageIndicator", {
							Character = self.instance,
							Amount = entry.Amount,
						})
				end
			else
				self.Humanoid.Health =
					math.min(self.Humanoid.Health + entry.Amount, self.Humanoid.MaxHealth)
			end

			if self.Humanoid.Health <= 0 then
				table.clear(state.Queue)
				break
			end
			if state.Generation ~= generation then break end
			if #state.Queue > 0 then task.wait(0.05) end
		end

		if state.Generation == generation then state.Draining = false end
	end)
end

return {
	["MaxWalkSpeed"] = WalkSpeedWatcher,
	["MinWalkSpeed"] = WalkSpeedWatcher,

	["MaxJumpPower"] = function(self: types.Character, value)
		const jumpPower = MovementRules.GetJumpPower(value)

		self.Humanoid.JumpPower = jumpPower
		-- Characters spawn in JumpHeight mode, where JumpPower is ignored entirely;
		-- the height has to be scaled alongside it for a jump block to take effect.
		self.Humanoid.JumpHeight = (jumpPower / MovementRules.BaseJumpPower)
			* StarterPlayer.CharacterJumpHeight
	end,

	["Stun"] = function(
		self: types.Character,
		value: { Priority: number, Duration: number }?,
		object
	)
		if not value then return end

		const VFXService = Crane:GetService("VFXService")
		const Stunned = value.Priority ~= Enums.Stun.None

		if Stunned then
			VFXService:StartEffect(Players:GetPlayers(), "Stunned", { Character = self.instance })
		else
			VFXService:StopEffect(Players:GetPlayers(), "Stunned", { Character = self.instance })
		end

		if not object then return end

		const Priority = value.Priority

		object.Cleaner:Add(self:AddParameter("MaxJumpPower", 0))

		if Priority == Enums.Stun.Heavy then
			object.Cleaner:Add(self:AddParameter("MaxWalkSpeed", 0))
		elseif Priority == Enums.Stun.Medium then
			object.Cleaner:Add(self:AddParameter("MaxWalkSpeed", 3))
		end
	end,

	["Bleeding"] = function(self: types.Character, value, object)
		const Bleeding = value ~= nil and (value.Damage or 0) > 0
		const VFXService = Crane:GetService("VFXService")

		-- Blood and the slowdown are a state, not a one-shot effect: the watcher
		-- fires on every change of the parameter and syncs both with it, so an
		-- effect removed from the outside (a future cleanse, for example) stops
		-- them without a separate branch anywhere.
		if Bleeding then
			VFXService:StartEffect(Players:GetPlayers(), "Bleeding", { Character = self.instance })
		else
			VFXService:StopEffect(Players:GetPlayers(), "Bleeding", { Character = self.instance })
		end

		if not Bleeding or not object then return end

		if not object.Cleaner:Has("Slow") then
			object.Cleaner:Set("Slow", self:AddParameter("MaxWalkSpeed", value.Slow or 8))
		end
	end,

	["Burning"] = function(self: types.Character, value, object)
		const burning = value ~= nil and (value.Damage or 0) > 0
		const VFXService = Crane:GetService("VFXService")

		-- The flames are a state, not a one-shot effect: the watcher syncs them
		-- with the parameter, so a burn removed from the outside stops them too.
		if burning then
			VFXService:StartEffect(Players:GetPlayers(), "Burning", {
				Character = self.instance,
				Rig = burningRig(),
			})
		else
			VFXService:StopEffect(Players:GetPlayers(), "Burning", { Character = self.instance })
		end

		if not burning or not object then return end

		if value.Slow and not object.Cleaner:Has("Slow") then
			object.Cleaner:Set("Slow", self:AddParameter("MaxWalkSpeed", value.Slow))
		end
	end,

	["NoDeath"] = NoDeathWatcher,

	["DamageHold"] = DamageHoldWatcher,

	["Ragdoll"] = function(self: types.Character, value: boolean?, object)
		value = value or false
		self:Ragdoll(value)

		if value then
			const iframe = self:AddParameter("IFrames", Enums.IFrames.Ragdoll)

			object.Cleaner:OnClean(function()
				task.delay(0.4, function()
					iframe:Destroy()
				end)
			end)
		end
	end,

	["NoCollision"] = function(
		self: types.Character,
		value: boolean,
		object: types.ParameterObject<boolean>
	)
		self:SetCollisionToPlayers(value ~= nil and value or true)
	end,

	["Restrain"] = function(self: types.Character, value: boolean, object)
		if not value then return end

		self.Humanoid.AutoRotate = not value
		--self.RootPart.Anchored = value

		object.Cleaner:Add(self:AddParameter("MaxWalkSpeed", 0))
		object.Cleaner:Add(self:AddParameter("MaxJumpPower", 0))

		object.Cleaner:Add(function()
			self.Humanoid.AutoRotate = true
			--self.RootPart.Anchored = false
		end)
	end,
}
