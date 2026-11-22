const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

const Crane = require(ReplicatedStorage.shared.packages.Crane)
const CombatConfig = require(ReplicatedStorage.shared.configs.Combat)
const types = require(ServerScriptService.server.types)

--[=[
	Owns the replicated `CharacterState.InCombat` flag.

	Combat is a time window, not a latch: every landed hit extends it by
	`CombatConfig.CombatTimeout` seconds, and death or a respawn clears it at
	once. The flag lives in the dynamic part of the player schema, so it is
	replicated to the client but never written to the save document.

	CharacterAdder hands us each character it builds. Doing our own listening
	with `OnTakeDamage` (instead of hooking the damage chain) keeps this module
	out of the combat hooks and makes the "took damage" rule explicit.
]=]

const CombatStateModule = {
	Name = "CombatStateModule",
} :: types.PlayerModule

function CombatStateModule.onInit(self: typeof(CombatStateModule))
	self.Character = nil
	self.Scope = nil
	self.Generation = 0
	self.CombatUntil = 0
	self.InCombat = false
end

function CombatStateModule.onStart(_self: typeof(CombatStateModule)) end

--- While a window is merely being extended, only the deadline needs to travel.
--- Re-publishing the boolean on every hit of a barrage would be pointless
--- traffic and would wake every subscriber for no state change.
function CombatStateModule.Publish(
	self: typeof(CombatStateModule),
	expiresAt: number,
	includeFlag: boolean
)
	const instructions = {}

	if includeFlag then
		table.insert(instructions, {
			Name = "SetDictionary",
			Path = { "CharacterState" },
			Args = { "InCombat", self.InCombat },
		})
	end

	table.insert(instructions, {
		Name = "SetDictionary",
		Path = { "CharacterState" },
		Args = { "CombatUntil", expiresAt },
	})

	self.playerProxy:Patch(instructions)
end

function CombatStateModule.EnterCombat(self: typeof(CombatStateModule))
	const now = workspace:GetServerTimeNow()
	const alreadyOpen = self.InCombat and now < self.CombatUntil
	const generation = self.Generation + 1
	self.Generation = generation
	self.InCombat = true

	const expiresAt = now + CombatConfig.CombatTimeout
	self.CombatUntil = expiresAt
	self:Publish(expiresAt, not alreadyOpen)

	-- A single pending expiry per window. A new hit bumps the generation, so
	-- this older timer becomes a no-op instead of clearing a fresh window.
	task.delay(CombatConfig.CombatTimeout, function()
		if self.Generation ~= generation then return end
		self:LeaveCombat()
	end)
end

function CombatStateModule.LeaveCombat(self: typeof(CombatStateModule))
	if not self.InCombat then return end

	self.Generation += 1
	self.InCombat = false
	self.CombatUntil = 0
	self:Publish(0, true)
end

function CombatStateModule.OnTakeDamage(self: typeof(CombatStateModule), _attacker: any, data: any)
	const info = data and data.Info
	const damage = if info then (info.Damage or 0) else 0
	if damage <= 0 then return end

	self:EnterCombat()
end

function CombatStateModule.OnCharacter(self: typeof(CombatStateModule), character: types.Character)
	-- A new rig means a fresh window. Destroy the old scope first so a stale
	-- OnTakeDamage from the previous body cannot re-enter combat after respawn.
	if self.Scope then self.Scope:Destroy() end

	self.Character = character
	self.Scope = Crane.Buttler.new()
	self.Generation += 1
	self.InCombat = false
	self.CombatUntil = 0
	self:Publish(0, true)

	self.Scope:Connect(character.OnTakeDamage, function(attacker, data)
		self:OnTakeDamage(attacker, data)
	end)
	self.Scope:Connect(character.Humanoid.Died, function()
		self:LeaveCombat()
	end)
	self.Scope:Connect(character.Destroying, function()
		self:LeaveCombat()
	end)
end

return CombatStateModule
